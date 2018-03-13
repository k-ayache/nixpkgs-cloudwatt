{ fetched ? import ./nixpkgs-fetch.nix {}
, nixpkgs ? fetched.pkgs
, contrail ? fetched.contrail
}:

let pkgs = import nixpkgs {};
    lib =  import ./pkgs/lib pkgs;
    deps =  import ./pkgs/deps.nix pkgs;

    callPackage = pkgs.lib.callPackageWith (
      pkgs // cwPkgs // { inherit pkgs lib deps callPackage; });
    callPackages = pkgs.lib.callPackagesWith (
      pkgs // cwPkgs // { inherit pkgs lib deps callPackage; });

    cwPkgs = rec {
      ci = callPackage ./ci { };

      perp = callPackage ./pkgs/perp { };

      contrail32Cw = import ./pkgs/contrail32Cw {
        inherit pkgs;
        contrailPath = contrail;
        nixpkgsPath = nixpkgs;
      };

      debianPackages = callPackages ./pkgs/debian-packages { contrailPkgs = contrail32Cw; };
      dockerImages = callPackages ./pkgs/docker-images { contrailPath = contrail; nixpkgs = nixpkgs; };

      tools = callPackages ./pkgs/tools { };

      locksmith = callPackage ./pkgs/vault-fernet-locksmith { };

      waitFor = callPackage ./pkgs/wait-for {};

      test.hydra = callPackage ./test/hydra.nix { pkgs_path = nixpkgs; hydraImage = ci.hydraImage; };
    };

in cwPkgs
