{ callPackage, callPackages, pkgs, lib, contrail32Cw, locksmith, contrailPath, nixpkgs, waitFor, fluentdCw }:

callPackages ./contrail { inherit contrailPath; } //
{
  hydra = callPackage ./hydra { };

  locksmithWorker = callPackage ./locksmithWorker { };

  gremlinServer = callPackage ./gremlin-server { };

  gremlinFsck = callPackage ./gremlin-fsck { };

  skydiveAnalyzer = callPackage ./skydive { };
}
