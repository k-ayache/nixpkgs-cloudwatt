{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    # Belong to the branch release-18.03
    rev = "0a73111bc29565d60fbe094a996177f3053809e3";
    sha256 = "12gs6r6w09jwlqciw6a954wqqw2lj1f3mp7ng1qg4v82aca9dmgy";};
  contrail = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs-contrail";
    # Belong to the master branch
    rev = "043fb365260c178622c0f18cf84b7ad7290e1a8b";
    sha256 = "0cfmj0mqn2q6d4xvgjy9ix1lp6vyf9y0ypl4v6mnvqm5aq9m53cp";};
  }
