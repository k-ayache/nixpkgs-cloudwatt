{ pkgs, ... }:

{

  kubernetesBaseImage = pkgs.dockerTools.pullImage {
    imageName = "r.cwpriv.net/kubernetes/base";
    imageTag = "16.04-3a4f5ba7a528f04e";
    sha256 = "0baj7ibdan6v1n0xvgna3iq0z84r7xs27jrpcmzwn0fs63ip27nz";
  };

  javaJreImage = pkgs.dockerTools.pullImage {
    imageName = "r.cwpriv.net/java/jre";
    imageTag = "8-16.04-217a2260b5fb49b4";
    sha256 = "1cq6lcyl9hpwdy7f53hminx2i0vp86zrbgglh2y27pf9ciaycql9";
  };

}
