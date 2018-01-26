{ pkgs, lib, contrail32Cw, locksmith }:

let
  configuration = import ./configuration.nix pkgs;

  buildContrailImageWithPerp = name: command: preStartScript:
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
  contrailApi = buildContrailImageWithPerp "opencontrail/api"
    "${contrail32Cw.api}/bin/contrail-api --conf_file /etc/contrail/contrail-api.conf"
    ''consul-template-wrapper -- -once  -template="${configuration.contrailApi}:/etc/contrail/contrail-api.conf"'';
  contrailDiscovery = buildContrailImageWithPerp "opencontrail/discovery"
    "${contrail32Cw.discovery}/bin/contrail-discovery --conf_file /etc/contrail/contrail-discovery.conf"
    ''consul-template-wrapper -- -once  -template="${configuration.contrailDiscovery}:/etc/contrail/contrail-discovery.conf"'';
  contrailControl = buildContrailImageWithPerp "opencontrail/control"
    "${contrail32Cw.control}/bin/contrail-control --conf_file /etc/contrail/contrail-control.conf"
    ''consul-template-wrapper -- -once  -template="${configuration.contrailControl}:/etc/contrail/contrail-control.conf"'';
  contrailCollector = buildContrailImageWithPerp "opencontrail/collector"
    "${contrail32Cw.collector}/bin/contrail-collector --conf_file /etc/contrail/contrail-collector.conf"
    ''consul-template-wrapper -- -once  -template="${configuration.contrailCollector}:/etc/contrail/contrail-collector.conf"'';
  contrailAnalyticsApi = buildContrailImageWithPerp "opencontrail/analytics-api"
    "${contrail32Cw.analyticsApi}/bin/contrail-analytics-api --conf_file /etc/contrail/contrail-analytics-api.conf"
    ''consul-template-wrapper -- -once  -template="${configuration.contrailAnalyticsApi}:/etc/contrail/contrail-analytics-api.conf"'';
  contrailSchemaTransformer = buildContrailImageWithPerp "opencontrail/schema-transformer"
    "${contrail32Cw.schemaTransformer}/bin/contrail-schema --conf_file /etc/contrail/contrail-schema-transformer.conf"
    ''consul-template-wrapper -- -once  -template="${configuration.contrailSchemaTransformer}:/etc/contrail/contrail-schema-transformer.conf"'';
  contrailSvcMonitor = buildContrailImageWithPerp "opencontrail/svc-monitor"
    "${contrail32Cw.svcMonitor}/bin/contrail-svc-monitor --conf_file /etc/contrail/contrail-svc-monitor.conf"
    ''consul-template-wrapper -- -once  -template="${configuration.contrailSvcMonitor}:/etc/contrail/contrail-svc-monitor.conf"'';

  locksmithWorker = lib.buildImageWithPerp {
    name = "locksmith/worker";
    command = "${locksmith}/bin/vault-fernet-locksmith";
    preStartScript = ""; };
}
