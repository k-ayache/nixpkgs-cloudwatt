{ stdenv, lib, buildGoPackage, fetchFromGitHub }:

buildGoPackage rec {
  name = "consul-template-mock-${version}";
  version = "2018-06-28";

  goPackagePath = "github.com/nlewo/consul-template-mock";

  src = fetchFromGitHub {
    owner = "nlewo";
    repo = "consul-template-mock";
    rev = "ca7ecf505598d50f6c6480177a31e1ed8a8cf7d6";
    sha256 = "0lz3hrz4adrqgabq5ag6nlpgglcsnz3abj81m60xwz8l2lzpgyhn";
  };

  meta = with stdenv.lib; {
    homepage = https://github.com/nlewo/consul-template-mock;
    description = "Render consul-template templates without Consul";
    licenses = [ licenses.gpl3 ];
    maintainers = [ maintainers.lewo ];
  };
}
