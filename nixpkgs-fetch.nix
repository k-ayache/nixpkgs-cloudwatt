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
    rev = "9c7728f41f4349870af6eb0f03b29cc153ffc307";
    sha256 = "1s797zw4anim2z1hw6v059y9w68xy1nximijnpdg8vg3nzr64niz";};
  }
