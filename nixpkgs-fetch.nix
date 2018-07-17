{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    # Belong to the branch release-18.03
    rev = "2ee48415afc58cb9043a2463e0bde1a91d46c09a";
    sha256 = "1fca1mfpzb2r4ijxllrcyl8qzbws9wxlvqr3fsh4agrpkf68rci5";};
  contrail = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs-contrail";
    # Belong to the master branch
    rev = "c6b4e9b0b715cfcf0991c7586fe95f1771c318d0";
    sha256 = "005y4xyhdyzb11cvmqr3zx7sz4vsw4lclyq2gf7bscgq15sj7lhk";};
  }
