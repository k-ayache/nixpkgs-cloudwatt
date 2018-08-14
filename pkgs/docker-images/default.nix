{ callPackage, pkgs, lib, contrail32Cw, locksmith, contrailPath, nixpkgs, waitFor, fluentdCw }:

let

  config = {
    contrail = import ./config/contrail { inherit pkgs; };
    gremlin = import ./config/gremlin { inherit pkgs contrail32Cw; };
    locksmith = import ./config/locksmith { inherit pkgs lib; };
  };

in
{
  contrailVrouter = callPackage ./contrail-vrouter {
    inherit contrailPath;
    contrailPkgs = contrail32Cw;
    configFiles = config;
  };

  hydra = callPackage ./hydra { };

  contrailApi = lib.buildContrailImageWithPerp {
    name = "opencontrail/api";
    command = "${contrail32Cw.api}/bin/contrail-api --conf_file /run/consul-template-wrapper/contrail/contrail-api.conf";
    preStartScript = lib.myIp + ''
      consul-template-wrapper -- -once \
        -template="${config.contrail.api}:/run/consul-template-wrapper/contrail/contrail-api.conf" \
        -template="${config.contrail.vncApiLib}:/run/consul-template-wrapper/contrail/vnc_api_lib.ini"
    '';
    fluentd = config.contrail.fluentdForPythonService;
  };

  contrailDiscovery = lib.buildContrailImageWithPerp {
    name = "opencontrail/discovery";
    command = "${contrail32Cw.discovery}/bin/contrail-discovery --conf_file /run/consul-template-wrapper/contrail/contrail-discovery.conf";
    preStartScript = lib.myIp + ''
      consul-template-wrapper -- -once \
        -template="${config.contrail.discovery}:/run/consul-template-wrapper/contrail/contrail-discovery.conf"
    '';
    fluentd = config.contrail.fluentdForPythonService;
  };

  contrailControl = lib.buildContrailImageWithPerp {
    name = "opencontrail/control";
    command = "${contrail32Cw.control}/bin/contrail-control --conf_file /run/consul-template-wrapper/contrail/contrail-control.conf";
    preStartScript = ''
      ${waitFor}/bin/wait-for \
        ${config.contrail.services.discovery.dns}:${toString config.contrail.services.discovery.port}
      consul-template-wrapper -- -once \
        -template="${config.contrail.control}:/run/consul-template-wrapper/contrail/contrail-control.conf"
    '';
    fluentd = config.contrail.fluentdForCService;
  };

  contrailAnalytics = lib.buildContrailImageWithPerps {
    name = "opencontrail/analytics";
    services = [
      {
        name = "consul-template";
        oneShot = true;
        preStartScript = lib.myIp;
        command = ''
          /usr/sbin/consul-template-wrapper -- -once \
            -template="${config.contrail.analyticsApi}:/run/consul-template-wrapper/contrail/contrail-analytics-api.conf" \
            -template="${config.contrail.collector}:/run/consul-template-wrapper/contrail/contrail-collector.conf" \
            -template="${config.contrail.queryEngine}:/run/consul-template-wrapper/contrail/contrail-query-engine.conf" \
            -template="${config.contrail.vncApiLib}:/run/consul-template-wrapper/contrail/vnc_api_lib.ini"
        '';
        user = "root";
      }
      {
        name = "redis-server";
        command = "${pkgs.redis}/bin/redis-server --bind 0.0.0.0";
      }
      {
        name = "opencontrail-analytics-api";
        command = "${contrail32Cw.analyticsApi}/bin/contrail-analytics-api --conf_file /run/consul-template-wrapper/contrail/contrail-analytics-api.conf";
        fluentd = config.contrail.fluentdForPythonService;
        after = ["consul-template"];
      }
      {
        name = "opencontrail-collector";
        command = "${contrail32Cw.collector}/bin/contrail-collector --conf_file /run/consul-template-wrapper/contrail/contrail-collector.conf";
        fluentd = config.contrail.fluentdForCService;
        after = ["consul-template"];
      }
      {
        name = "opencontrail-query-engine";
        command = "${contrail32Cw.queryEngine}/bin/qed --conf_file /run/consul-template-wrapper/contrail/contrail-query-engine.conf";
        fluentd = config.contrail.fluentdForCService;
        after = ["consul-template"];
      }
    ];
  };

  contrailSchemaTransformer = lib.buildContrailImageWithPerp {
    name = "opencontrail/schema-transformer";
    command = "${contrail32Cw.schemaTransformer}/bin/contrail-schema --conf_file /run/consul-template-wrapper/contrail/contrail-schema-transformer.conf";
    preStartScript = ''
      consul-template-wrapper -- -once \
        -template="${config.contrail.schemaTransformer}:/run/consul-template-wrapper/contrail/contrail-schema-transformer.conf" \
        -template="${config.contrail.vncApiLib}:/run/consul-template-wrapper/contrail/vnc_api_lib.ini"
    '';
    fluentd = config.contrail.fluentdForPythonService;
  };

  contrailSvcMonitor = lib.buildContrailImageWithPerp {
    name = "opencontrail/svc-monitor";
    command = "${contrail32Cw.svcMonitor}/bin/contrail-svc-monitor --conf_file /run/consul-template-wrapper/contrail/contrail-svc-monitor.conf";
    preStartScript = ''
      consul-template-wrapper -- -once \
        -template="${config.contrail.svcMonitor}:/run/consul-template-wrapper/contrail/contrail-svc-monitor.conf" \
        -template="${config.contrail.vncApiLib}:/run/consul-template-wrapper/contrail/vnc_api_lib.ini"
    '';
    fluentd = config.contrail.fluentdForPythonService;
  };

  locksmithWorker = lib.buildImageWithPerp {
    name = "locksmith/worker";
    fromImage = lib.images.kubernetesBaseImage;
    command = "${locksmith}/bin/vault-fernet-locksmith -logtostderr -config-file-dir /run/consul-template-wrapper/etc/locksmith -config-file config";
    preStartScript = ''
      consul-template-wrapper -- -once \
        -template "${config.locksmith}:/run/consul-template-wrapper/etc/locksmith/config.yaml"
    '';
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

  skydiveAnalyzer = callPackage ./skydive { };
}
