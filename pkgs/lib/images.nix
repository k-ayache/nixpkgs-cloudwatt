{ pkgs, ... }:

{

  kubernetesBaseImage = pkgs.dockerTools.pullImage {
    imageName = "docker-registry.sec.cloudwatt.com/kubernetes/base";
    imageTag = "16.04-861a9e3cd4c7cb3e";
    sha256 = "1q22fm4y5jc5bs6pcg6pcf26aaz6jqfdz5svv31ax2wmvza0r2l1";
  };

  javaJreImage = pkgs.dockerTools.pullImage {
    imageName = "docker-registry.sec.cloudwatt.com/java/jre";
    imageTag = "8-16.04-217a2260b5fb49b4";
    sha256 = "13i6q99m8v9v64iz9qnd2svkgs7srlgnh9k54rgyrp8d8sjy6qaa";
  };

}
