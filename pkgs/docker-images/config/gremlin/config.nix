{ pkgs, contrail32Cw }:

rec {

  fsckConf = pkgs.writeTextFile {
    name = "vars.ctmpl";
    text = ''
      {{ $openstack_region := env "openstack_region" -}}
      {{ $catalog := key (printf "/config/openstack/catalog/%s/data" $openstack_region) | parseJSON -}}

      export OS_AUTH_URL={{ $catalog.identity.internal_url }}
      export OS_USERNAME=deployment
      export OS_TENANT_NAME=deployment
      {{ with secret "secret/openstack/users/deployment" -}}
      export OS_PASSWORD={{ .Data.password }}
      {{- end }}
      export OS_ENDPOINT_TYPE=internalURL
      export OS_AUTH_PLUGIN=v2password

      export CONTRAIL_API_HOST=contrail-api

      export GREMLIN_FSCK_SERVER=gremlin-server-pods.service:8182
      export GREMLIN_FSCK_LOOP=1
      export GREMLIN_FSCK_JSON=1
      export GREMLIN_FSCK_ZK_SERVER=opencontrail-config-zookeeper.service:2181
    '';
  };

  fsckPreStart = ''
    consul-template-wrapper -- -once \
      -template "${fsckConf}:/run/consul-template-wrapper/vars" && \
    source /run/consul-template-wrapper/vars
  '';

  dumpPath = "/tmp/dump.gson";

  serverConf = pkgs.writeTextFile {
    name = "server.yaml";
    text = builtins.readFile ./server.yaml + ''
      graphs: {
        graph: ${serverProperties}
      }
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

  serverPreStart = ''
    export GREMLIN_DUMP_CASSANDRA_SERVERS=opencontrail-config-cassandra.service
    # We can't modify the parent image, so we do it at runtime
    if [ -f /etc/prometheus/prometheus_jmx_java8.yml ] && ! grep -q 'metrics<name'
    then
      echo "- pattern: 'metrics<name=(.+)><>(.+):'" >> /etc/prometheus/prometheus_jmx_java8.yml
    fi
    if [ -f /etc/default/prometheus_jmx ]
    then
      source /etc/default/prometheus_jmx
      export JAVA_OPTIONS="$JAVA_OPTIONS -Dcom.sun.management.jmxremote $PROM_OPTS"
    fi
    export JAVA_OPTIONS="$JAVA_OPTIONS -Dlog4j.configuration=file:${log4jProperties}"
    ${contrail32Cw.tools.contrailGremlin}/bin/gremlin-dump ${dumpPath}
  '';

  syncConf = pkgs.writeTextFile {
    name = "vars.ctmpl";
    text = ''
      export GREMLIN_SYNC_CASSANDRA_SERVERS=opencontrail-config-cassandra.service
      export GREMLIN_SYNC_RABBIT_SERVER=opencontrail-queue.service:5672
      {{ with secret "secret/opencontrail" -}}
      export GREMLIN_SYNC_RABBIT_PASSWORD={{ .Data.queue_password }}
      {{- end }}
      export GREMLIN_SYNC_RABBIT_VHOST=opencontrail
      export GREMLIN_SYNC_RABBIT_USER=opencontrail
      export GREMLIN_SYNC_RABBIT_QUEUE=gremlin_sync.$HOSTNAME
      export GREMLIN_LOG_NO_COLOR=1
    '';
  };

  syncPreStart = ''
    consul-template-wrapper -- -once \
      -template "${syncConf}:/run/consul-template-wrapper/vars" && \
    source /run/consul-template-wrapper/vars
  '';

}
