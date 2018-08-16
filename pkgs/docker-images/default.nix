{ callPackage, callPackages, contrailPath }:

callPackages ./contrail { inherit contrailPath; } //
{
  hydra = callPackage ./hydra { };

  locksmithWorker = callPackage ./locksmithWorker { };

  gremlinServer = callPackage ./gremlin-server { };

  gremlinFsck = callPackage ./gremlin-fsck { };

  skydiveAnalyzer = callPackage ./skydive { };
}
