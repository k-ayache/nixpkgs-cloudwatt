{ stdenv, buildGoPackage, fetchFromGitHub, lib }:

buildGoPackage rec {
  name = "kube2consul-${version}";
  version = "2.1.3";
  goPackagePath = "github.com/cloudwatt/kube2consul";

  src = fetchFromGitHub {
    owner = "cloudwatt";
    repo = "kube2consul";
    rev = "v${version}";
    sha256 = "1argjr26519j77rcs4gp4cmgsg1hx7xiifds1707hmnn1y7b3g0h";
  };

  buildFlagsArray = ''
    -ldflags= -X main.kube2consulVersion=v${version}'';

  meta = {
    homepage = https://github.com/cloudwatt/kube2consul;
    description = "Push kubernetes services into Consul";
    licenses = [ lib.licenses.gpl ];
    platforms = [ "x86_64-linux" ];
    maintainers = [ {github = "lightcode";} ];
  };
}
