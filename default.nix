{ fetched ? import ./nixpkgs-fetch.nix {}
, nixpkgs ? fetched.pkgs
, contrail ? fetched.contrail
}:

let pkgs = import nixpkgs {};
    lib =  import ./lib pkgs;

    allPackages = import (contrail + "/all-packages.nix") { inherit pkgs nixpkgs; };

    # Override sources attribute to use the Cloudwatt repositories instead of Contrail repositories
    overrideContrailPkgs = self: super: {
      sources = super.sources32 // (import ./sources.nix { inherit pkgs; });
      contrailVersion = self.contrail32;
      thirdPartyCache = super.thirdPartyCache.overrideAttrs(oldAttrs:
        { outputHash = "1rvj0dkaw4jbgmr5rkdw02s1krw1307220iwmf2j0p0485p7d3h2"; });
    };
    contrailPkgsCw = pkgs.lib.fix (pkgs.lib.extends overrideContrailPkgs allPackages);

    configuration = import ./configuration.nix pkgs;

    buildContrailImageWithPerp = name: command: preStartScript:
      lib.buildImageWithPerp {
        inherit name command preStartScript;
        extraCommands = "chmod u+w etc; mkdir -p var/log/contrail etc/contrail";
     };

in rec {
  ci.hydraImage = import ./ci {inherit pkgs;};
 
  contrail32Cw = with contrailPkgsCw; {
    inherit api control vrouterAgent
            collector analyticsApi discovery
            queryEngine schemaTransformer svcMonitor
            configUtils vrouterUtils
            vrouterNetns vrouterPortControl
            webCore
            test
            vms;
  };

  images = {
    contrailApi = buildContrailImageWithPerp "opencontrail/api"
      "${contrail32Cw.api}/bin/contrail-api --conf_file /etc/contrail/contrail-api.conf"
      ''consul-template-wrapper -- -once  -template="${configuration.api}:/etc/contrail/contrail-api.conf"'';
    contrailDiscovery = buildContrailImageWithPerp "opencontrail/discovery"
      "${contrail32Cw.discovery}/bin/contrail-discovery --conf_file /etc/contrail/contrail-discovery.conf"
      ''consul-template-wrapper -- -once  -template="${configuration.discovery}:/etc/contrail/contrail-discovery.conf"'';
    contrailControl = buildContrailImageWithPerp "opencontrail/control"
      "${contrail32Cw.control}/bin/contrail-control --conf_file /etc/contrail/contrail-control.conf"
      ''consul-template-wrapper -- -once  -template="${configuration.control}:/etc/contrail/contrail-control.conf"'';
    contrailCollector = buildContrailImageWithPerp "opencontrail/collector"
      "${contrail32Cw.collector}/bin/contrail-collector --conf_file /etc/contrail/contrail-collector.conf"
      ''consul-template-wrapper -- -once  -template="${configuration.collector}:/etc/contrail/contrail-collector.conf"'';
    contrailAnalyticsApi = buildContrailImageWithPerp "opencontrail/analytics-api"
      "${contrail32Cw.analyticsApi}/bin/contrail-analytics-api --conf_file /etc/contrail/contrail-analytics-api.conf"
      ''consul-template-wrapper -- -once  -template="${configuration.analytics-api}:/etc/contrail/contrail-analytics-api.conf"'';
    contrailSchemaTransformer = buildContrailImageWithPerp "opencontrail/schema-transformer"
      "${contrail32Cw.schemaTransformer}/bin/contrail-schema --conf_file /etc/contrail/contrail-schema-transformer.conf"
      ''consul-template-wrapper -- -once  -template="${configuration.schema-transformer}:/etc/contrail/contrail-schema-transformer.conf"'';
    contrailSvcMonitor = buildContrailImageWithPerp "opencontrail/svc-monitor"
      "${contrail32Cw.svcMonitor}/bin/contrail-svc-monitor --conf_file /etc/contrail/contrail-svc-monitor.conf"
      ''consul-template-wrapper -- -once  -template="${configuration.svc-monitor}:/etc/contrail/contrail-svc-monitor.conf"'';

  };

  debianPackages = import ./debian-packages.nix { contrailPkgs=contrailPkgsCw; inherit pkgs; };

  # This build an Ubuntu vm where Debian packages are
  # preinstalled. This is used to easily try generated Debian
  # packages.
  tools.installDebianPackages = lib.runUbuntuVmScript [
    debianPackages.contrailVrouterUbuntu_3_13_0_83_generic
    debianPackages.contrailVrouterUserland
  ];
}

