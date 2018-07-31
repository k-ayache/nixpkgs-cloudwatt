{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    # Belong to the branch release-18.03
    rev = "6796f5db1c2a25aeade10d613ddb403e4eb7a928";
    sha256 = "0fmvh1wcr1rgsr6cv8bpw5rmm9ypg94q7h9s4xqzaq567d3nhhhz";};
  contrail = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs-contrail";
    # Belong to the master branch
    rev = "c6b4e9b0b715cfcf0991c7586fe95f1771c318d0";
    sha256 = "005y4xyhdyzb11cvmqr3zx7sz4vsw4lclyq2gf7bscgq15sj7lhk";};
  }
