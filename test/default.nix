{ callPackage, ci, cwPkgs, contrailPath, contrailPkgs }:

{
  hydra = callPackage ./hydra.nix { hydraImage = ci.hydraImage; };

  fluentd = callPackage ./fluentd.nix { };

  perp = callPackage ./perp.nix { };

  contrail = callPackage ./contrail.nix {
    inherit contrailPath cwPkgs contrailPkgs;
  };

  contrailLoadDatabase = callPackage ./contrail-load-database.nix {
    inherit contrailPath contrailPkgs;
  };

  gremlinDump = callPackage ./gremlin-dump.nix {
    inherit contrailPath contrailPkgs;
  };

  # to run these tests:
  # nix-instantiate --eval --strict -A test.lib
  lib = callPackage ../pkgs/lib/tests.nix { };
}
