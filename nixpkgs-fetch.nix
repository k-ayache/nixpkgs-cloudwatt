{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs";
    # Part of the branch release-17.09-cloudwatt
    rev = "0c41433868ad61aac43da184c113f305a3784957";
    sha256 = "0jrlk9wwbskzw2bxvncna1fi4qm596r83smcfh1dashb8gm3ddp8";};
  contrail = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs-contrail";
    rev = "b252f9d1727554dc292b26507a9395f330a1c598";
    sha256 = "0jrlk9wwbskzw2bxvncna1fi4qm596r83smcfh1dashb8gm3ddp8";};
  }
