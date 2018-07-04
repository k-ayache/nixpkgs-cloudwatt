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
    rev = "ec32d48aa1cd285f16d989a889c9802be3866510";
    sha256 = "1qc8jn81rdi4q568jb6208m62pr5n1wcvxjl4lymw8ggrxk22mzm";};
  }
