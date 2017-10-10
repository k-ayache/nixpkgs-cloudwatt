{ fetched ? import ./nixpkgs-fetch.nix {}
, nixpkgs ? fetched.pkgs
, contrail ? fetched.contrail
}:


let pkgs = import nixpkgs {};
    lib =  import ./lib pkgs;
    contrailPkgs = import contrail { pkgs_path = nixpkgs; };
    configuration = import ./configuration.nix pkgs;

    # Take a list of image description and generate an attribute set
    generateImages = images: builtins.listToAttrs (builtins.map (a:
      { name = a.attr;
        value = lib.buildImageWithPerp a.name a.command; }) images);

in rec {
  ci.hydraImage = import ./ci {inherit pkgs;};
  contrail = contrailPkgs;
  images =  generateImages [
    { attr = "contrailApi";
      name = "opencontrail/api";
      command = "${contrailPkgs.contrailApi}/bin/contrail-api --conf_file ${configuration.api}";
    }
    { attr = "contrailDiscovery";
      name = "opencontrail/discovery";
      command = "${contrailPkgs.contrailDiscovery}/bin/contrail-discovery --conf_file ${configuration.discovery}";
    }
    { attr = "contrailControl";
      name = "opencontrail/control";
      command = "${contrailPkgs.contrailControl}/bin/contrail-control --conf_file ${configuration.control}";
    }
  ];
  debianPackages = import ./debian-packages.nix {inherit pkgs contrailPkgs;};

  # Useful to dev Debian packages
  tools.installDebianPackages = lib.runUbuntuVmScript [
    debianPackages.contrailVrouterUbuntu_3_13_0_83_generic
    debianPackages.contrailVrouterUserland
  ];
}

