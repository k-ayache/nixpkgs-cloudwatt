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
    contrailVrouter = {
      ubuntu_3_13_0_83_generic = lib.mkDebianPackage rec {
        name = "contraill-vrouter-module";
        contents = contrailPkgs.contrailVrouter deps.ubuntuKernelHeaders_3_13_0_83_generic;
        linkScript = ''
          vrouterRelativePath=$(find ${contents} -name vrouter.ko -printf '%P')
          vrouterRelativeDir=$(dirname $vrouterRelativePath)
          mkdir -p $vrouterRelativeDir

          vrouterPath=$(find ${contents} -name vrouter.ko)
          ln -s $vrouterPath $vrouterRelativeDir
        '';
        };
      };
    contrailVrouterUserland = lib.mkDebianPackage rec {
      name = "contraill-vrouter-userland";
      contents = [
        contrailPkgs.contrailVrouterAgent contrailPkgs.contrailVrouterPortControl contrailPkgs.contrailVrouterUtils ];
      linkScript = ''
        for path in ${pkgs.lib.foldl (a: b: a + " " + b) "" contents};
        do
          find $path/bin/ -type f >> files
        done
        mkdir -p usr/bin
        echo "Link binaries found in contents"
        cat files | xargs -I'{}' -t ln -s '{}' usr/bin/
        rm files
      '';
      };
  };
}
