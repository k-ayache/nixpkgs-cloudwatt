{ pkgs, contrail32Cw }:

rec {

  fsckEnv = pkgs.writeTextFile {
    name = "env.ctmpl";
    text = ''
      {{ $openstack_region := env "openstack_region" -}}
      {{ $catalog := key (printf "/config/openstack/catalog/%s/data" $openstack_region) | parseJSON -}}
      OS_AUTH_URL={{ $catalog.identity.internal_url }}
      OS_USERNAME=deployment
      OS_TENANT_NAME=deployment
      {{ with secret "secret/openstack/users/deployment" -}}
      OS_PASSWORD={{ .Data.password }}
      {{- end }}
      OS_ENDPOINT_TYPE=internalURL
      OS_AUTH_PLUGIN=v2password

      CONTRAIL_API_HOST=contrail-api

      GREMLIN_FSCK_SERVER=gremlin-server-pods.service:8182
      GREMLIN_FSCK_LOOP=1
      GREMLIN_FSCK_JSON=1
      GREMLIN_FSCK_ZK_SERVER=opencontrail-config-zookeeper.service:2181
    '';
  };

  fsckPreStart = ''
    consul-template-wrapper -- -once -template "${fsckEnv}:/run/consul-template-wrapper/env"
  '';

  dumpPath = "/tmp/dump.gson";

  serverConf = pkgs.writeTextFile {
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

  serverProperties = pkgs.writeTextFile {
    name = "server.properties";
    text = ''
      gremlin.graph=org.apache.tinkerpop.gremlin.tinkergraph.structure.TinkerGraph
      gremlin.tinkergraph.vertexIdManager=UUID
      gremlin.tinkergraph.graphFormat=graphson
      gremlin.tinkergraph.graphLocation=${dumpPath}
    '';
  };

  serverScript = pkgs.writeTextFile {
    name = "server.groovy";
    text = ''
      def globals = [:]

      globals << [g : graph.traversal(), n : graph.traversal().withStrategies(SubgraphStrategy.build().vertices(hasNot('_missing').hasNot('_incomplete')).create())]
    '';
  };

  log4jProperties = pkgs.writeTextFile {
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

  prometheusJmxExporter = pkgs.fetchurl {
    url = "https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.10/jmx_prometheus_javaagent-0.10.jar";
    sha256 = "0abyydm2dg5g57alpvigymycflgq4b3drw4qs7c65vn95yiaai5i";
  };

  prometheusJmxExporterConf = pkgs.writeTextFile {
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

  serverPreStart = ''
    export JAVA_OPTIONS="$JAVA_OPTIONS -Dlog4j.configuration=file:${log4jProperties} -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -javaagent:${prometheusJmxExporter}=1234:${prometheusJmxExporterConf}"
    export GREMLIN_DUMP_CASSANDRA_SERVERS=opencontrail-config-cassandra.service
    ${contrail32Cw.tools.contrailGremlin}/bin/gremlin-dump ${dumpPath}
  '';

  syncEnv = pkgs.writeTextFile {
    name = "env.ctmpl";
    text = ''
      GREMLIN_SYNC_CASSANDRA_SERVERS=opencontrail-config-cassandra.service
      GREMLIN_SYNC_RABBIT_SERVER=opencontrail-queue.service:5672
      {{ with secret "secret/opencontrail" -}}
      GREMLIN_SYNC_RABBIT_PASSWORD={{ .Data.queue_password }}
      {{- end }}
      GREMLIN_SYNC_RABBIT_VHOST=opencontrail
      GREMLIN_SYNC_RABBIT_USER=opencontrail
      GREMLIN_SYNC_RABBIT_QUEUE=gremlin_sync.$HOSTNAME
      GREMLIN_LOG_NO_COLOR=1
    '';
  };

  syncPreStart = ''
    consul-template-wrapper -- -once -template "${syncEnv}:/run/consul-template-wrapper/env"
  '';

}
