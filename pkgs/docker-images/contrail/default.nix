{ callPackage, pkgs, lib, contrail32Cw, contrailPath, waitFor, redis }:

let config = import ./config.nix { inherit pkgs; };

in {
  contrailVrouter = callPackage ./vrouter {
    inherit contrailPath;
    contrailPkgs = contrail32Cw;
    configFiles = { contrail = config; };
  };

  contrailApi = lib.buildContrailImageWithPerp {
    name = "opencontrail/api";
    command = "${contrail32Cw.api}/bin/contrail-api --conf_file /run/consul-template-wrapper/contrail/contrail-api.conf";
    preStartScript = lib.myIp + ''
      consul-template-wrapper -- -once \
        -template="${config.api}:/run/consul-template-wrapper/contrail/contrail-api.conf" \
        -template="${config.vncApiLib}:/run/consul-template-wrapper/contrail/vnc_api_lib.ini"
    '';
    fluentd = config.fluentdForPythonService;
  };

  contrailDiscovery = lib.buildContrailImageWithPerp {
    name = "opencontrail/discovery";
    command = "${contrail32Cw.discovery}/bin/contrail-discovery --conf_file /run/consul-template-wrapper/contrail/contrail-discovery.conf";
    preStartScript = lib.myIp + ''
      consul-template-wrapper -- -once \
        -template="${config.discovery}:/run/consul-template-wrapper/contrail/contrail-discovery.conf"
    '';
    fluentd = config.fluentdForPythonService;
  };

  contrailControl = lib.buildContrailImageWithPerp {
    name = "opencontrail/control";
    command = "${contrail32Cw.control}/bin/contrail-control --conf_file /run/consul-template-wrapper/contrail/contrail-control.conf";
    preStartScript = ''
      ${waitFor}/bin/wait-for \
        ${config.services.discovery.dns}:${toString config.services.discovery.port}
      consul-template-wrapper -- -once \
        -template="${config.control}:/run/consul-template-wrapper/contrail/contrail-control.conf"
    '';
    fluentd = config.fluentdForCService;
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
            -template="${config.analyticsApi}:/run/consul-template-wrapper/contrail/contrail-analytics-api.conf" \
            -template="${config.collector}:/run/consul-template-wrapper/contrail/contrail-collector.conf" \
            -template="${config.queryEngine}:/run/consul-template-wrapper/contrail/contrail-query-engine.conf" \
            -template="${config.vncApiLib}:/run/consul-template-wrapper/contrail/vnc_api_lib.ini"
        '';
        user = "root";
      }
      {
        name = "redis-server";
        command = "${redis}/bin/redis-server --bind 0.0.0.0";
      }
      {
        name = "opencontrail-analytics-api";
        command = "${contrail32Cw.analyticsApi}/bin/contrail-analytics-api --conf_file /run/consul-template-wrapper/contrail/contrail-analytics-api.conf";
        fluentd = config.fluentdForPythonService;
        after = ["consul-template"];
      }
      {
        name = "opencontrail-collector";
        command = "${contrail32Cw.collector}/bin/contrail-collector --conf_file /run/consul-template-wrapper/contrail/contrail-collector.conf";
        fluentd = config.fluentdForCService;
        after = ["consul-template"];
      }
      {
        name = "opencontrail-query-engine";
        command = "${contrail32Cw.queryEngine}/bin/qed --conf_file /run/consul-template-wrapper/contrail/contrail-query-engine.conf";
        fluentd = config.fluentdForCService;
        after = ["consul-template"];
      }
    ];
  };

  contrailSchemaTransformer = lib.buildContrailImageWithPerp {
    name = "opencontrail/schema-transformer";
    command = "${contrail32Cw.schemaTransformer}/bin/contrail-schema --conf_file /run/consul-template-wrapper/contrail/contrail-schema-transformer.conf";
    preStartScript = ''
      consul-template-wrapper -- -once \
        -template="${config.schemaTransformer}:/run/consul-template-wrapper/contrail/contrail-schema-transformer.conf" \
        -template="${config.vncApiLib}:/run/consul-template-wrapper/contrail/vnc_api_lib.ini"
    '';
    fluentd = config.fluentdForPythonService;
  };

  contrailSvcMonitor = lib.buildContrailImageWithPerp {
    name = "opencontrail/svc-monitor";
    command = "${contrail32Cw.svcMonitor}/bin/contrail-svc-monitor --conf_file /run/consul-template-wrapper/contrail/contrail-svc-monitor.conf";
    preStartScript = ''
      consul-template-wrapper -- -once \
        -template="${config.svcMonitor}:/run/consul-template-wrapper/contrail/contrail-svc-monitor.conf" \
        -template="${config.vncApiLib}:/run/consul-template-wrapper/contrail/vnc_api_lib.ini"
    '';
    fluentd = config.fluentdForPythonService;
  };
}
