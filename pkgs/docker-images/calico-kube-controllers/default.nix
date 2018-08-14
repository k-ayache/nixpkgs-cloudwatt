{ lib, calicoKubeControllers}:

lib.buildImageWithPerp {
    name = "calico/kube-controllers";
    fromImage = lib.images.kubernetesBaseImage;
    command = "${calicoKubeControllers}/bin/kube-controllers";
}
