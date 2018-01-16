{ fetched ? import ./nixpkgs-fetch.nix {}
, nixpkgs ? fetched.pkgs
, contrail ? fetched.contrail
}:

let pkgs = import nixpkgs {};
    lib =  import ./pkgs/lib pkgs;
    deps =  import ./pkgs/deps.nix pkgs;

    callPackage = pkgs.lib.callPackageWith (
      cwPkgs // { inherit pkgs lib deps callPackage; } // { inherit (pkgs) stdenv fetchurl; });
    callPackages = pkgs.lib.callPackagesWith (
      cwPkgs // { inherit pkgs lib deps callPackage; } // { inherit (pkgs) stdenv fetchurl; });

    cwPkgs = rec {
      ci = callPackage ./ci { };

      perp = callPackage ./pkgs/perp { }; 

      contrail32Cw = callPackages ./pkgs/contrail32Cw {
        contrailPath = contrail;
        nixpkgsPath = nixpkgs;
      };

      debianPackages = callPackages ./pkgs/debian-packages { contrailPkgs = contrail32Cw; };
      dockerImages = callPackages ./pkgs/docker-images { };

      tools = callPackages ./pkgs/tools { };
    };

in cwPkgs
