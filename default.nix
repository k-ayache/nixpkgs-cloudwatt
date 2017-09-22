{ fetched ? import ./nixpkgs-fetch.nix {}
, nixpkgs ? fetched.pkgs
, contrail ? fetched.contrail
}:


let pkgs = import nixpkgs {};
    lib =  import ./lib pkgs;
    deps = import ./deps.nix pkgs;
    contrailPkgs = import contrail { pkgs_path = nixpkgs; };
    configuration = import ./configuration.nix pkgs;

    # Take a list of image description and generate an attribute set
    generateImages = images: builtins.listToAttrs (builtins.map (a:
      { name = a.attr;
        value = lib.buildImageWithPerp a.name a.command; }) images);
in {
  ci.hydraImage = import ./ci {inherit pkgs;};
  contrail = contrailPkgs;
  images =  generateImages [
    { attr = "contrailApi";
      name = "contrail-api";
      command = "${contrailPkgs.contrailApi}/bin/contrail-api --conf_file ${configuration.api}";
    }
    { attr = "contrailDiscovery";
      name = "contrail-discovery";
      command = "${contrailPkgs.contrailDiscovery}/bin/contrail-discovery --conf_file ${configuration.discovery}";
    }
  ];
  debianPackages = {
    contrailVrouterUbuntu_3_13_0_83_generic = lib.mkDebianPackage (
      contrailPkgs.contrailVrouter deps.ubuntuKernelHeaders_3_13_0_83_generic);
  };
}
