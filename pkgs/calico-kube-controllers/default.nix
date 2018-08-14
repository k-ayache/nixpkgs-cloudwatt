{ stdenv, buildGoPackage, fetchFromGitHub }:

buildGoPackage rec {
  name = "calico-kube-controllers-${version}";
  version = "3.1.3";
  goPackagePath = "github.com/projectcalico/kube-controllers";

  src = fetchFromGitHub {
    owner = "projectcalico";
    repo = "kube-controllers";
    rev = "v${version}";
    sha256 = "0dswmrk9zslsr9d758nq6ysxm6phicca38l7qss4mkfh7sj2yhja";
  };

  goDeps = ./deps.nix;

  preBuild = ''
    find go/src -name vendor | xargs -I % sh -c 'echo Removing %; rm -rf %'
  '';

  buildFlagsArray = ''
    -ldflags= -X main.VERSION=v${version}'';
}
