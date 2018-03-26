{ pkgs, lib, contrail32Cw, locksmith, contrailPath, nixpkgs, waitFor, fluentdCw }:

let

  config = {
    contrail = import ./config/contrail.nix pkgs;
    gremlin = import ./config/gremlin/config.nix { inherit pkgs contrail32Cw waitFor; };
  };

  buildContrailImageWithPerp = { name, command, preStartScript }:
    lib.buildImageWithPerp {
      inherit name command;
      fromImage = lib.images.kubernetesBaseImage;
      preStartScript = ''
        # hack to populate the configuration with the container ip
        # with consul-template it is only possible to read a file
        hostname --ip-address > /my-ip
      '' + preStartScript;
      extraCommands = "chmod u+w etc; mkdir -p var/log/contrail etc/contrail";
  };

  contrailVrouter = import ./contrail-vrouter {
    inherit waitFor contrailPath;
    pkgs_path = nixpkgs;
    contrailPkgs = contrail32Cw;
    configFiles = config;
  };

in
{
  inherit contrailVrouter;

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
      ${waitFor}/bin/wait-for \
        ${config.contrail.services.discovery.dns}:${toString config.contrail.services.discovery.port}
      consul-template-wrapper -- -once \
        -template="${config.contrail.control}:/etc/contrail/contrail-control.conf"
    '';
  };

  contrailCollector = buildContrailImageWithPerp {
    name = "opencontrail/collector";
    command = "${contrail32Cw.collector}/bin/contrail-collector --conf_file /etc/contrail/contrail-collector.conf";
    preStartScript = ''
      ${waitFor}/bin/wait-for \
        ${config.contrail.services.discovery.dns}:${toString config.contrail.services.discovery.port}
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
    fromImage = lib.images.kubernetesBaseImage;
    command = "${locksmith}/bin/vault-fernet-locksmith";
    preStartScript = "";
  };

  gremlinServer = lib.buildImageWithPerps {
    name = "gremlin/server";
    fromImage = lib.images.javaJreImage;
    services = [
      {
        name = "gremlin-server";
        preStartScript = config.gremlin.serverPreStart;
        chdir = "${contrail32Cw.tools.gremlinServer}/opt";
        command = ''
          rundeux ${contrail32Cw.tools.gremlinServer}/bin/gremlin-server ${config.gremlin.serverConf} :: ${pkgs.coreutils}/bin/tee /tmp/gremlin-server
        '';
      }
      {
        name = "gremlin-sync";
        preStartScript = config.gremlin.syncPreStart;
        command = ''
          rundeux ${contrail32Cw.tools.contrailGremlin}/bin/gremlin-sync :: ${pkgs.coreutils}/bin/tee /tmp/gremlin-sync
        '';
      }
      {
        name = "fluentd";
        preStartScript = ''
          # named pipes to collect services logs
          [ ! -p /tmp/gremlin-server ] && mkfifo /tmp/gremlin-server
          [ ! -p /tmp/gremlin-sync ] && mkfifo /tmp/gremlin-sync
        '';
        command = "${fluentdCw}/bin/fluentd --no-supervisor -c ${config.gremlin.fluentdServer}";
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
        command = ''
          rundeux ${contrail32Cw.tools.contrailApiCliWithExtra}/bin/contrail-api-cli fsck :: ${pkgs.coreutils}/bin/tee /tmp/gremlin-fsck
        '';
      }
      {
        name = "fluentd";
        preStartScript = ''
          # named pipe to collect service logs
          [ ! -p /tmp/gremlin-fsck ] && mkfifo /tmp/gremlin-fsck
        '';
        command = "${fluentdCw}/bin/fluentd --no-supervisor -c ${config.gremlin.fluentdFsck}";
      }
    ];
  };

}
