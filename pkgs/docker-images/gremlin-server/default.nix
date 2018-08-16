{ lib, contrail32Cw, writeTextFile, fetchurl }:

let
  serverPreStart = ''
    export JAVA_OPTIONS="$JAVA_OPTIONS -Dlog4j.configuration=file:${log4jProperties} -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -javaagent:${prometheusJmxExporter}=1234:${prometheusJmxExporterConf}"
    export GREMLIN_DUMP_CASSANDRA_SERVERS=opencontrail-config-cassandra.service
    ${contrail32Cw.tools.contrailGremlin}/bin/gremlin-dump ${dumpPath}
  '';

  serverConf = writeTextFile {
    name = "server.yaml";
    text = builtins.readFile ./server.yaml + ''
      graphs: {
        graph: ${serverProperties}
      }
      scriptEngines: {
        gremlin-groovy: {
          plugins: { org.apache.tinkerpop.gremlin.server.jsr223.GremlinServerGremlinPlugin: {},
                     org.apache.tinkerpop.gremlin.tinkergraph.jsr223.TinkerGraphGremlinPlugin: {},
                     org.apache.tinkerpop.gremlin.jsr223.ScriptFileGremlinPlugin: { files: [${serverScript}] }}}}
    '';
  };

  serverScript = writeTextFile {
    name = "server.groovy";
    text = ''
      def globals = [:]

      globals << [g : graph.traversal(), n : graph.traversal().withStrategies(SubgraphStrategy.build().vertices(hasNot('_missing').hasNot('_incomplete').has('deleted', 0)).create())]
    '';
  };

  dumpPath = "/tmp/dump.gson";

  serverProperties = writeTextFile {
    name = "server.properties";
    text = ''
      gremlin.graph=org.apache.tinkerpop.gremlin.tinkergraph.structure.TinkerGraph
      gremlin.tinkergraph.vertexIdManager=UUID
      gremlin.tinkergraph.graphFormat=graphson
      gremlin.tinkergraph.graphLocation=${dumpPath}
    '';
  };

  syncPreStart = ''
    consul-template-wrapper -- -once -template "${syncEnv}:/run/consul-template-wrapper/env"
    export GREMLIN_SYNC_RABBIT_QUEUE=gremlin_sync.$HOSTNAME
  '';

  log4jProperties = writeTextFile {
    name = "log4j.properties";
    text = ''
      log4j.rootLogger=INFO, stdout
      log4j.appender.stdout=org.apache.log4j.ConsoleAppender
      log4j.appender.stdout.layout=org.apache.log4j.EnhancedPatternLayout
      log4j.appender.stdout.layout.ConversionPattern=%d{HH:mm:ss.SSS} %C{1} [%p] %m%n%throwable{0}

      log4j.logger.org.apache.tinkerpop.gremlin.driver.Connection=OFF
      log4j.logger.org.apache.tinkerpop.gremlin.driver.ConnectionPool=OFF
    '';
  };

  prometheusJmxExporter = fetchurl {
    url = "https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.10/jmx_prometheus_javaagent-0.10.jar";
    sha256 = "0abyydm2dg5g57alpvigymycflgq4b3drw4qs7c65vn95yiaai5i";
  };

  prometheusJmxExporterConf = writeTextFile {
    name = "prometheus_jmx_java8.yml";
    text = ''
      ---
      rules:
      - pattern: 'java.nio<type=BufferPool, name=(\w+)><>(Count|MemoryUsed):'
      - pattern: 'java.lang<type=GarbageCollector, name=(\w+)><>(\w+):'
      - pattern: 'java.lang<type=Compilation><>(TotalCompilationTime):'
      - pattern: 'java.lang<type=OperatingSystem><>(AvailableProcessors|CommittedVirtualMemorySize|FreePhysicalMemorySize|FreeSwapSpaceSize|MaxFileDescriptorCount|OpenFileDescriptorCount|ProcessCpuLoad|ProcessCpuTime|SystemCpuLoad|SystemLoadAverage|TotalPhysicalMemorySize|TotalSwapSpaceSize):'
      - pattern: 'java.lang<type=Threading><>(CurrentThreadCpuTime|CurrentThreadUserTime):'
      - pattern: 'metrics<name=(.+)><>(.+):'
    '';
  };

  syncEnv = writeTextFile {
    name = "env.ctmpl";
    text = ''
      GREMLIN_SYNC_CASSANDRA_SERVERS=opencontrail-config-cassandra.service
      GREMLIN_SYNC_RABBIT_SERVER=opencontrail-queue.service:5672
      {{ with secret "secret/opencontrail" -}}
      GREMLIN_SYNC_RABBIT_PASSWORD={{ .Data.queue_password }}
      {{- end }}
      GREMLIN_SYNC_RABBIT_VHOST=opencontrail
      GREMLIN_SYNC_RABBIT_USER=opencontrail
      GREMLIN_LOG_NO_COLOR=1
    '';
  };

in
  lib.buildImageWithPerps {
    name = "gremlin/server";
    fromImage = lib.images.kubernetesBaseImage;
    services = [
      {
        name = "gremlin-server";
        preStartScript = serverPreStart;
        chdir = "${contrail32Cw.tools.gremlinServer}/opt";
        command = "${contrail32Cw.tools.gremlinServer}/bin/gremlin-server ${serverConf}";
        fluentd = {
          source = {
            type = "stdout";
            time_format = "%H:%M:%S.%L";
            format = ''/^(?<time>[^ ]+) (?<classname>[^ ]+) \[(?<level>[^\]]+)\] (?<message>.*)$/'';
          };
        };
      }
      {
        name = "gremlin-sync";
        preStartScript = syncPreStart;
        environmentFile = "/run/consul-template-wrapper/env";
        command = "${contrail32Cw.tools.contrailGremlin}/bin/gremlin-sync";
        fluentd = {
          source = {
            type = "stdout";
            time_format = "%H:%M:%S.%L";
            format = ''/^(?<time>[^ ]+) (?<funcname>[^ ]+) \[(?<level>[^\]]+)\] (?<message>.*)$/'';
          };
        };
      }
    ];
    contents = [
      contrail32Cw.tools.contrailGremlin
    ];
  }
