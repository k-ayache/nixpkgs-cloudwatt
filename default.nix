{ fetched ? import ./nixpkgs-fetch.nix {}
, nixpkgs ? fetched.pkgs
, contrail ? fetched.contrail
}:

let pkgs = import nixpkgs {};
    lib =  import ./pkgs/lib { inherit pkgs cwPkgs; };
    deps =  import ./pkgs/deps.nix pkgs;

    callPackage = pkgs.lib.callPackageWith (
      pkgs // cwPkgs // { inherit pkgs lib deps callPackage; });
    callPackages = pkgs.lib.callPackagesWith (
      pkgs // cwPkgs // { inherit pkgs lib deps callPackage; });

    cwPkgs = rec {

      ci = callPackage ./ci { };

      perp = callPackage ./pkgs/perp { };

      fluentd = callPackage ./pkgs/fluentd { };

      fluentdCw = callPackage ./pkgs/fluentdCw { };

      consulTemplateMock = callPackage ./pkgs/consul-template-mock { };

      contrail32Cw = import ./pkgs/contrail32Cw {
        inherit pkgs;
        contrailPath = contrail;
        nixpkgsPath = nixpkgs;
      };

      debianPackages = callPackages ./pkgs/debian-packages { contrailPkgs = contrail32Cw; };
      dockerImages = callPackages ./pkgs/docker-images { contrailPath = contrail; nixpkgs = nixpkgs; };

      tools = callPackages ./pkgs/tools { };

      locksmith = callPackage ./pkgs/vault-fernet-locksmith { };

      skydive = callPackage ./pkgs/skydive {};

      waitFor = callPackage ./pkgs/wait-for {};

      openstackClient = callPackage ./pkgs/openstackclient {};

      test.hydra = callPackage ./test/hydra.nix { pkgs_path = nixpkgs; hydraImage = ci.hydraImage; };
      test.fluentd = callPackage ./test/fluentd.nix { pkgs_path = nixpkgs; cwPkgs = cwPkgs; };
      test.perp = callPackage ./test/perp.nix { pkgs_path = nixpkgs; };
      test.contrail = callPackage ./test/contrail.nix {
        pkgs_path = nixpkgs; cwPkgs = cwPkgs; contrailPath = contrail; contrailPkgs = contrail32Cw;
      };
      test.contrailLoadDatabase = callPackage ./test/contrail-load-database.nix {
        contrailPath = contrail; contrailPkgs = contrail32Cw;
      };

      # to run these tests:
      # nix-instantiate --eval --strict -A test.lib
      test.lib = callPackage ./pkgs/lib/tests.nix {};

    };

in cwPkgs
