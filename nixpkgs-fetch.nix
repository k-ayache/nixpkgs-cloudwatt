{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    # Belong to the branch release-18.03-cloudwatt
    rev = "bccc513396e6ea410cae660e64510f417653bbe4";
    sha256 = "1h8j6h5spal06k4pnvcxmxpi2v6sm9b88snkq25pkdpyyci1zdwi";};
  contrail = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs-contrail";
    # Belong to the master branch
    rev = "4a5b598d1e0dcb7c7c07e042e37fecc3b72c2d26";
    sha256 = "1srijcmv7y9g4xpmfm55yh3210pzl0w8qdzzjfik72a2my6956ry";};
  }
