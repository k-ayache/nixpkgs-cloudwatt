{ callPackage, callPackages, contrailPath }:

callPackages ./contrail { inherit contrailPath; } //
{
  hydra = callPackage ./hydra { };

  locksmithWorker = callPackage ./locksmithWorker { };

  calicoKubeControllers = callPackage ./calico-kube-controllers { };

  gremlinServer = callPackage ./gremlin-server { };

  gremlinFsck = callPackage ./gremlin-fsck { };

  skydiveAnalyzer = callPackage ./skydive { };
}
