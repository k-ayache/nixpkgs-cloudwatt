pkgs:

{

  kubernetesBaseImage = pkgs.dockerTools.pullImage {
    imageName = "r.cwpriv.net/kubernetes/base";
    imageTag = "16.04-c6e9c969951cf94b";
    sha256 = "0gksw7l0mbdhmjvb0mvb48h5ay9qr7sqsxq4hs3cfla9kn73l5cd";
  };

  javaJreImage = pkgs.dockerTools.pullImage {
    imageName = "r.cwpriv.net/java/jre";
    imageTag = "8-16.04-217a2260b5fb49b4";
    sha256 = "1cq6lcyl9hpwdy7f53hminx2i0vp86zrbgglh2y27pf9ciaycql9";
  };

}
