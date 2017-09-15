{ fetched ? import ./nixpkgs-fetch.nix {}
, nixpkgs ? fetched.pkgs
, contrail ? fetched.contrail
}:


let pkgs = import nixpkgs {};
    lib =  import ./lib pkgs;
    contrailPkgs = import contrail { inherit pkgs; };
in
  {
    ci.hydra = import ./ci {inherit pkgs;};
    contrail = contrailPkgs;
    images = builtins.listToAttrs (builtins.map (a: { name = a.attr; value = lib.buildImageWithPerp a.name a.cmd; }) [
      { attr = "contrailApi";
        name = "contrail-api";
        cmd = "${contrailPkgs.contrailApi}/bin/contrail-api";
      }
      { attr = "contrailDiscovery";
        name = "contrail-discovery";
        cmd = "${contrailPkgs.contrailDiscovery}/bin/contrail-discovery";
      }
    ]);
  }
