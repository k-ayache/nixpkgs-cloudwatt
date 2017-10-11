{ fetched ? import ./nixpkgs-fetch.nix {}
, nixpkgs ? fetched.pkgs
, contrail ? fetched.contrail
}:


let pkgs = import nixpkgs {};
    lib =  import ./lib pkgs;
    contrailFn = import (contrail + "/all-packages.nix") { inherit pkgs nixpkgs; };
    contrailPkgs = pkgs.lib.fix contrailFn;
    configuration = import ./configuration.nix pkgs;

    # Take a list of image description and generate an attribute set
    generateImages = images: builtins.listToAttrs (builtins.map (a:
      { name = a.attr;
        value = lib.buildImageWithPerp a.name a.command; }) images);

in rec {
  ci.hydraImage = import ./ci {inherit pkgs;};
  contrail32 = with contrailPkgs.contrail32; {
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
      command = "${contrail32.api}/bin/contrail-api --conf_file ${configuration.api}";
    }
    { attr = "contrailDiscovery";
      name = "opencontrail/discovery";
      command = "${contrail32.discovery}/bin/contrail-discovery --conf_file ${configuration.discovery}";
    }
    { attr = "contrailControl";
      name = "opencontrail/control";
      command = "${contrail32.control}/bin/contrail-control --conf_file ${configuration.control}";
    }
  ];
  debianPackages = import ./debian-packages.nix { contrailPkgs=contrail32; inherit pkgs; };

  # Useful to dev Debian packages
  tools.installDebianPackages = lib.runUbuntuVmScript [
    debianPackages.contrailVrouterUbuntu_3_13_0_83_generic
    debianPackages.contrailVrouterUserland
  ];
}

