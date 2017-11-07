{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs";
    # Belong to the branch release-17.09-cloudwatt
    rev = "cb5ac615101c5ef346a88648f918685f39f335d8";
    sha256 = "0lrn1vvbli82zkcq32dkkj56b1l008bmpw2zyhmsw85ajqw8imab";};
  contrail = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs-contrail";
    # Belong to the master branch
    rev = "cf3e243e3b7cd0b17ea32f81b781b7c7a74f0995";
    sha256 = "1bddf959cd8ka5i5f4qqrnsz9dl0panqv5ps3z055419ksi5a0w0";};
  }
