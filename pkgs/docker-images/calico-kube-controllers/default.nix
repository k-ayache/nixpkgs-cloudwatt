{ lib, calicoKubeControllers }:

lib.buildImageWithPerp {
  name = "calico/kube-controllers";
  command = "${calicoKubeControllers}/bin/kube-controllers";
}
