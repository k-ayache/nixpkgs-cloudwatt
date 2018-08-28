{ lib, contrail32Cw, writeTextFile }:

let
  fsckEnv = writeTextFile {
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
      CONTRAIL_API_CLI_CONFIG_DIR=/tmp

      GREMLIN_FSCK_SERVER=gremlin-server-pods.service:8182
      GREMLIN_FSCK_LOOP=1
      GREMLIN_FSCK_JSON=1
      GREMLIN_FSCK_ZK_SERVER=opencontrail-config-zookeeper.service:2181
    '';
  };

  fsckPreStart = ''
    consul-template-wrapper -- -once -template "${fsckEnv}:/run/consul-template-wrapper/env"
  '';
in
  lib.buildImageWithPerps {
    name = "gremlin/fsck";
    services = [
      {
        name = "gremlin-fsck";
        preStartScript = fsckPreStart;
        environmentFile = "/run/consul-template-wrapper/env";
        command = "${contrail32Cw.tools.contrailApiCliWithExtra}/bin/contrail-api-cli fsck";
        fluentd = {
          source = {
            type = "stdout";
            format = "json";
          };
        };
      }
    ];
  }
