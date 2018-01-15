{ fetched ? import ./nixpkgs-fetch.nix {}
, nixpkgs ? fetched.pkgs
, contrail ? fetched.contrail
}:

let pkgs = import nixpkgs {};
    lib =  import ./lib pkgs;
    deps =  import ./deps.nix pkgs;

    configuration = import ./configuration.nix pkgs;

    buildContrailImageWithPerp = name: command: preStartScript:
      lib.buildImageWithPerp {
        inherit name command preStartScript;
        extraCommands = "chmod u+w etc; mkdir -p var/log/contrail etc/contrail";
     };

    callPackage = pkgs.lib.callPackageWith (
      cwPkgs // { inherit pkgs lib; } // { inherit (pkgs) stdenv fetchurl; });

    cwPkgs = rec {
      ci = callPackage ./ci { };

      perp = callPackage ./pkgs/perp { }; 

      contrail32Cw = callPackage ./pkgs/contrail32Cw {
        contrailPath = contrail;
        nixpkgsPath = nixpkgs;
      };

      images = {
        contrailApi = buildContrailImageWithPerp "opencontrail/api"
          "${contrail32Cw.api}/bin/contrail-api --conf_file ${configuration.api}";
        contrailDiscovery = buildContrailImageWithPerp "opencontrail/discovery"
          "${contrail32Cw.discovery}/bin/contrail-discovery --conf_file ${configuration.discovery}";
        contrailControl = buildContrailImageWithPerp "opencontrail/control"
          "${contrail32Cw.control}/bin/contrail-control --conf_file ${configuration.control}";
        contrailCollector = buildContrailImageWithPerp "opencontrail/collector"
          "${contrail32Cw.collector}/bin/contrail-collector --conf_file ${configuration.collector}";
        contrailAnalyticsApi = buildContrailImageWithPerp "opencontrail/analytics-api"
          "${contrail32Cw.analyticsApi}/bin/contrail-analytics-api --conf_file ${configuration.analytics-api}";
        contrailSchemaTransformer = buildContrailImageWithPerp "opencontrail/schema-transformer"
          "${contrail32Cw.schemaTransformer}/bin/contrail-schema --conf_file ${configuration.schema-transformer}";
        contrailSvcMonitor = buildContrailImageWithPerp "opencontrail/svc-monitor"
          "${contrail32Cw.svcMonitor}/bin/contrail-svc-monitor --conf_file ${configuration.svc-monitor}";
      };

      debianPackages = callPackage ./debian-packages.nix { contrailPkgs=contrail32Cw; };

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

in cwPkgs


