{ stdenv, lib, buildGoPackage, fetchFromGitHub }:

buildGoPackage rec {
  name = "consul-template-mock-${version}";
  version = "2018-06-21";

  goPackagePath = "github.com/nlewo/consul-template-mock";

  src = fetchFromGitHub {
    owner = "nlewo";
    repo = "consul-template-mock";
    rev = "a08de897efcbc1dc5c06bd6f6179ca93dc71140e";
    sha256 = "1y28hsvzz2p4cq7w7z6cpdrizkm05q57ffg7l3bv2gy90m4zl3am";
  };

  meta = with stdenv.lib; {
    homepage = https://github.com/nlewo/consul-template-mock;
    description = "Render consul-template templates without Consul";
    licenses = [ licenses.gpl3 ];
    maintainers = [ maintainers.lewo ];
  };
}
