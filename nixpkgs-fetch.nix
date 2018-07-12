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
    rev = "c1c8507cfa543935b66cb9011f4959af770afdd2";
    sha256 = "1r86cf6jbkanqxrdznivh0479xpzw3pnjmbwd2cj13mzb3iwglqn";};
  }
