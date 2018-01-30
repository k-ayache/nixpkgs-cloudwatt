{ pkgs, lib, contrail32Cw, locksmith }:

let
  config = {
    contrail = import ./config/contrail.nix pkgs;
  };

  buildContrailImageWithPerp = { name, command, preStartScript }:
    lib.buildImageWithPerp {
      inherit name command;
      preStartScript = ''
        # hack to populate the configuration with the container ip
        # with consul-template it is only possible to read a file
        hostname --ip-address > /my-ip
      '' + preStartScript;
      extraCommands = "chmod u+w etc; mkdir -p var/log/contrail etc/contrail";
  };

in
{

  contrailApi = buildContrailImageWithPerp {
    name = "opencontrail/api";
    command = "${contrail32Cw.api}/bin/contrail-api --conf_file /etc/contrail/contrail-api.conf";
    preStartScript = ''
      consul-template-wrapper -- -once \
        -template="${config.contrail.api}:/etc/contrail/contrail-api.conf"
    '';
  };

  contrailDiscovery = buildContrailImageWithPerp {
    name = "opencontrail/discovery";
    command = "${contrail32Cw.discovery}/bin/contrail-discovery --conf_file /etc/contrail/contrail-discovery.conf";
    preStartScript = ''
      consul-template-wrapper -- -once \
        -template="${config.contrail.discovery}:/etc/contrail/contrail-discovery.conf"
    '';
  };

  contrailControl = buildContrailImageWithPerp {
    name = "opencontrail/control";
    command = "${contrail32Cw.control}/bin/contrail-control --conf_file /etc/contrail/contrail-control.conf";
    preStartScript = ''
      consul-template-wrapper -- -once \
        -template="${config.contrail.control}:/etc/contrail/contrail-control.conf"
    '';
  };

  contrailCollector = buildContrailImageWithPerp {
    name = "opencontrail/collector";
    command = "${contrail32Cw.collector}/bin/contrail-collector --conf_file /etc/contrail/contrail-collector.conf";
    preStartScript = ''
      consul-template-wrapper -- -once \
        -template="${config.contrail.collector}:/etc/contrail/contrail-collector.conf"
    '';
  };

  contrailAnalyticsApi = buildContrailImageWithPerp {
    name = "opencontrail/analytics-api";
    command = "${contrail32Cw.analyticsApi}/bin/contrail-analytics-api --conf_file /etc/contrail/contrail-analytics-api.conf";
    preStartScript = ''
      consul-template-wrapper -- -once \
        -template="${config.contrail.analyticsApi}:/etc/contrail/contrail-analytics-api.conf"
    '';
  };

  contrailSchemaTransformer = buildContrailImageWithPerp {
    name = "opencontrail/schema-transformer";
    command = "${contrail32Cw.schemaTransformer}/bin/contrail-schema --conf_file /etc/contrail/contrail-schema-transformer.conf";
    preStartScript = ''
      consul-template-wrapper -- -once \
        -template="${config.contrail.schemaTransformer}:/etc/contrail/contrail-schema-transformer.conf"
    '';
  };

  contrailSvcMonitor = buildContrailImageWithPerp {
    name = "opencontrail/svc-monitor";
    command = "${contrail32Cw.svcMonitor}/bin/contrail-svc-monitor --conf_file /etc/contrail/contrail-svc-monitor.conf";
    preStartScript = ''
      consul-template-wrapper -- -once \
        -template="${config.contrail.svcMonitor}:/etc/contrail/contrail-svc-monitor.conf"
    '';
  };

  locksmithWorker = lib.buildImageWithPerp {
    name = "locksmith/worker";
    command = "${locksmith}/bin/vault-fernet-locksmith";
    preStartScript = "";
  };

}
