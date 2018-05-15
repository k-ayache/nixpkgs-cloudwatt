{ pkgs, lib, contrail32Cw, locksmith, contrailPath, nixpkgs, waitFor, fluentdCw }:

let

  config = {
    contrail = import ./config/contrail.nix pkgs;
    gremlin = import ./config/gremlin/config.nix { inherit pkgs contrail32Cw; };
    locksmith = import ./config/locksmith/config.nix { inherit pkgs; };
  };

  buildContrailImageWithPerp = { name, command, preStartScript, fluentd}:
    buildContrailImageWithPerps {
      inherit name;
        services = [
           {name = builtins.replaceStrings ["/"] ["-"] name;
            user = "root";
            inherit command preStartScript fluentd;
           }
        ];
    };

  buildContrailImageWithPerps = { name, services }:
    lib.buildImageWithPerps {
      inherit name services;
      fromImage = lib.images.kubernetesBaseImage;
      extraCommands = "chmod u+w etc; mkdir -p var/log/contrail etc/contrail";
    };

  contrailVrouter = import ./contrail-vrouter {
    inherit waitFor contrailPath;
    pkgs_path = nixpkgs;
    contrailPkgs = contrail32Cw;
    configFiles = config;
  };

  my_ip  = ''
    # hack to populate the configuration with the container ip
    # with consul-template it is only possible to read a file
    [[ ! -f /my-ip ]] && hostname --ip-address > /my-ip
    '';

  fluentdPython = {
    source = {
      type = "stdout";
    };
    filters = [
      {
        type = "parser";
        key_name = "message";
        parse = {
          type = "multi_format";
          pattern = [
            {
              format = "regexp";
              expression = ''/^(?<host>[^ ]*) [^ ]* (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^ ]*) +\S*)?" (?<code>[^ ]*) (?<size>[^ ]*)(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)")?(.*)?$/'';
            }
            {
              format = "regexp";
              expression = ''/^(?<time>([^ ]+ ){3})\[(?<serive>[^\]]+)\]: (?<message>.*)$/'';
            }
            {
              format = "none";
            }
          ];
        };
      }
    ];
  };

  fluentdC = {
    source = {
      type = "stdout";
    };
    filters = [
      {
        type = "parser";
        key_name = "message";
        parse = {
          type = "multi_format";
          pattern = [
            {
              format = "regexp";
              expression = ''/^(?<time>([^ ]+ ){4}) (?<idcontainer>[^ ]+) \[[^ ]+ (?<thread>[^,]+), [^ ]+(?<pid>[^\]]+)\]: (?<message>.*)$/'';
            }
            {
              format = "none";
            }
          ];
        };
      }
    ];
  };

in
{
  inherit contrailVrouter;

  contrailApi = buildContrailImageWithPerp {
    name = "opencontrail/api";
    command = "${contrail32Cw.api}/bin/contrail-api --conf_file /etc/contrail/contrail-api.conf";
    preStartScript = my_ip + ''
      consul-template-wrapper -- -once \
        -template="${config.contrail.api}:/etc/contrail/contrail-api.conf"
    '';
    fluentd = fluentdPython;
    };

  contrailDiscovery = buildContrailImageWithPerp {
    name = "opencontrail/discovery";
    command = "${contrail32Cw.discovery}/bin/contrail-discovery --conf_file /etc/contrail/contrail-discovery.conf";
    preStartScript = my_ip + ''
      consul-template-wrapper -- -once \
        -template="${config.contrail.discovery}:/etc/contrail/contrail-discovery.conf"
    '';
    fluentd = fluentdPython;
    };

  contrailControl = buildContrailImageWithPerp {
    name = "opencontrail/control";
    command = "${contrail32Cw.control}/bin/contrail-control --conf_file /etc/contrail/contrail-control.conf";
    preStartScript = ''
      ${waitFor}/bin/wait-for \
        ${config.contrail.services.discovery.dns}:${toString config.contrail.services.discovery.port}
      consul-template-wrapper -- -once \
        -template="${config.contrail.control}:/etc/contrail/contrail-control.conf"
    '';
    fluentd = fluentdC;
  };

  contrailAnalytics = buildContrailImageWithPerps {
    name = "opencontrail/analytics";
    services = [
      {
        name = "opencontrail-analytics-api";
        command = "${contrail32Cw.analyticsApi}/bin/contrail-analytics-api --conf_file /etc/contrail/contrail-analytics-api.conf";
        preStartScript = my_ip + ''
         /usr/sbin/consul-template-wrapper --token-file=/run/vault-token-analytics-api/vault-token -- -once \
         -template="${config.contrail.analyticsApi}:/etc/contrail/contrail-analytics-api.conf"
        '';
        user = "root";
        fluentd = fluentdPython;
      }
      {
        name = "opencontrail-collector";
        command = "${contrail32Cw.collector}/bin/contrail-collector --conf_file /etc/contrail/contrail-collector.conf";
        preStartScript = my_ip + ''
          ${waitFor}/bin/wait-for \
            ${config.contrail.services.discovery.dns}:${toString config.contrail.services.discovery.port}
         /usr/sbin/consul-template-wrapper --token-file=/run/vault-token-collector/vault-token -- -once \
         -template="${config.contrail.collector}:/etc/contrail/contrail-collector.conf" \
         -template="${config.contrail.vncApiLib}:/etc/contrail/vnc_api_lib.ini"
        '';
        user = "root";
        fluentd = fluentdC;
      }
      {
        name = "redis-server";
        command = "${pkgs.redis}/bin/redis-server --bind 127.0.0.1 $(hostname --ip-address)";
      }
      {
        name = "opencontrail-query-engine";
        command = "${contrail32Cw.queryEngine}/bin/qed --conf_file /etc/contrail/contrail-query-engine.conf";
        preStartScript = my_ip + ''
          /usr/sbin/consul-template-wrapper --token-file=/run/vault-token-query-engine/vault-token -- -once \
          -template="${config.contrail.queryEngine}:/etc/contrail/contrail-query-engine.conf"
          '';
        user = "root";
        fluentd = fluentdC;
      }
    ];
  };


  contrailSchemaTransformer = buildContrailImageWithPerp {
    name = "opencontrail/schema-transformer";
    command = "${contrail32Cw.schemaTransformer}/bin/contrail-schema --conf_file /etc/contrail/contrail-schema-transformer.conf";
    preStartScript = ''
      consul-template-wrapper -- -once \
        -template="${config.contrail.schemaTransformer}:/etc/contrail/contrail-schema-transformer.conf" \
        -template="${config.contrail.vncApiLib}:/etc/contrail/vnc_api_lib.ini"
    '';
    fluentd = fluentdPython;
  };

  contrailSvcMonitor = buildContrailImageWithPerp {
    name = "opencontrail/svc-monitor";
    command = "${contrail32Cw.svcMonitor}/bin/contrail-svc-monitor --conf_file /etc/contrail/contrail-svc-monitor.conf";
    preStartScript = ''
      consul-template-wrapper -- -once \
        -template="${config.contrail.svcMonitor}:/etc/contrail/contrail-svc-monitor.conf" \
        -template="${config.contrail.vncApiLib}:/etc/contrail/vnc_api_lib.ini"
    '';
    fluentd = fluentdPython;
  };

  locksmithWorker = lib.buildImageWithPerp {
    name = "locksmith/worker";
    fromImage = lib.images.kubernetesBaseImage;
    command = "${locksmith}/bin/vault-fernet-locksmith -logtostderr -config-file-dir /run/consul-template-wrapper/etc/locksmith -config-file config";
    preStartScript = config.locksmith.locksmithPreStart;
    user = "root";
  };

  gremlinServer = lib.buildImageWithPerps {
    name = "gremlin/server";
    fromImage = lib.images.kubernetesBaseImage;
    services = [
      {
        name = "gremlin-server";
        preStartScript = config.gremlin.serverPreStart;
        chdir = "${contrail32Cw.tools.gremlinServer}/opt";
        command = "${contrail32Cw.tools.gremlinServer}/bin/gremlin-server ${config.gremlin.serverConf}";
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
        preStartScript = config.gremlin.syncPreStart;
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
  };

  gremlinFsck = lib.buildImageWithPerps {
    name = "gremlin/fsck";
    fromImage = lib.images.kubernetesBaseImage;
    services = [
      {
        name = "gremlin-fsck";
        preStartScript = config.gremlin.fsckPreStart;
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
  };

}
