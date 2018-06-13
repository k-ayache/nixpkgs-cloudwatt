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
    rev = "0a16f54ecc81c7844b4e2ac7a2286b051474300d";
    sha256 = "1gmdjffjf8hg8ayjxc1gdafjjff6g0wwmg3ah94gnp06w5819ihk";};
  }
