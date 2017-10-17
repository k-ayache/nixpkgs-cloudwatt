{ fetched ? import ./nixpkgs-fetch.nix {}
, nixpkgs ? fetched.pkgs
, contrail ? fetched.contrail
}:


let pkgs = import nixpkgs {};
    lib =  import ./lib pkgs;
    contrailFn = import (contrail + "/all-packages.nix") { inherit pkgs nixpkgs; };

    # Override sources attribute to use the Cloudwatt repositories instead of Contrail repositories
    overrideContrailPkgs = self: super: { sources = super.sources // (import ./sources.nix {}); };
    contrailPkgsCw = pkgs.lib.fix (pkgs.lib.extends overrideContrailPkgs contrailFn);

    configuration = import ./configuration.nix pkgs;

    buildContrailImageWithPerp = name: command:
      lib.buildImageWithPerp {
        inherit name command;
        extraCommands = "mkdir -p var/log/contrail";
      };
    # Take a list of image description and generate an attribute set
    generateImages = images: builtins.listToAttrs (builtins.map (a:
      { name = a.attr;
        value = buildContrailImageWithPerp a.name a.command; }) images);

in rec {
  ci.hydraImage = import ./ci {inherit pkgs;};
  contrail32Cw = with contrailPkgsCw.contrail32; {
    inherit api control vrouterAgent
            collector analyticsApi discovery
            queryEngine
            configUtils vrouterUtils
            vrouterNetns vrouterPortControl
            webCore
            test
            vms;
    };
  images =  generateImages [
    { attr = "contrailApi";
      name = "opencontrail/api";
      command = "${contrail32Cw.api}/bin/contrail-api --conf_file ${configuration.api}";
    }
    { attr = "contrailDiscovery";
      name = "opencontrail/discovery";
      command = "${contrail32Cw.discovery}/bin/contrail-discovery --conf_file ${configuration.discovery}";
    }
    { attr = "contrailControl";
      name = "opencontrail/control";
      command = "${contrail32Cw.control}/bin/contrail-control --conf_file ${configuration.control}";
    }
    { attr = "contrailCollector";
      name = "opencontrail/collector";
      command = "${contrail32Cw.collector}/bin/contrail-collector --conf_file ${configuration.collector}";
    }
    { attr = "contrailAnalyticsApi";
      name = "opencontrail/analytics/api";
      command = "${contrail32Cw.analyticsApi}/bin/contrail-analytics-api --conf_file ${configuration.analytics-api}";
    }
  ];
  debianPackages = import ./debian-packages.nix { contrailPkgs=contrailPkgsCw.contrail32; inherit pkgs; };

  # Useful to dev Debian packages
  tools.installDebianPackages = lib.runUbuntuVmScript [
    debianPackages.contrailVrouterUbuntu_3_13_0_83_generic
    debianPackages.contrailVrouterUserland
  ];
}

