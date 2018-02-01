{ pkgs, contrail32Cw }:

let

  dumpPath = "/tmp/dump.gson";

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
    '';
  };

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

in {

  serverStart = pkgs.writeShellScriptBin "gremlin-server" ''
    export GREMLIN_DUMP_CASSANDRA_SERVERS=opencontrail-config-cassandra.service
    if [ -f /etc/default/prometheus_jmx ]
    then
      source /etc/default/prometheus_jmx
      export JAVA_OPTIONS="$JAVA_OPTIONS -Dcom.sun.management.jmxremote $PROM_OPTS"
    fi
    ${contrail32Cw.tools.contrailGremlin}/bin/gremlin-dump ${dumpPath} && \
    ${contrail32Cw.tools.gremlinServer.gremlinServer}/bin/gremlin-server ${serverConf}
  '';

  syncStart = pkgs.writeShellScriptBin "gremlin-sync" ''
    consul-template-wrapper -- -once \
      -template "${syncConf}:/run/consul-template-wrapper/vars" && \
    source /run/consul-template-wrapper/vars && \
    ${contrail32Cw.tools.contrailGremlin}/bin/gremlin-sync
  '';

}
