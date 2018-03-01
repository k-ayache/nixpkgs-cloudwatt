{ pkgs, contrail32Cw }:

let

  dumpPath = "/tmp/dump.gson";

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
    ${contrail32Cw.tools.gremlinServer}/bin/gremlin-server ${serverConf}
  '';

  syncStart = pkgs.writeShellScriptBin "gremlin-sync" ''
    consul-template-wrapper -- -once \
      -template "${syncConf}:/run/consul-template-wrapper/vars" && \
    source /run/consul-template-wrapper/vars && \
    ${contrail32Cw.tools.contrailGremlin}/bin/gremlin-sync
  '';

  fsckStart = pkgs.writeShellScriptBin "gremlin-fsck" ''
    consul-template-wrapper -- -once \
      -template "${fsckConf}:/run/consul-template-wrapper/vars" && \
    source /run/consul-template-wrapper/vars && \
    ${contrail32Cw.tools.contrailApiCliWithExtra}/bin/contrail-api-cli fsck
  '';

}
