{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    # Belong to the branch release-18.03
    rev = "699bc1278efa0e621083e731302076e2deca8ccd";
    sha256 = "19ci5s856zwbndldd6w5rhs1gzc7q350w8l2kpx94j790qh7v6nd";};
  contrail = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs-contrail";
    # Belong to the master branch
    rev = "043fb365260c178622c0f18cf84b7ad7290e1a8b";
    sha256 = "0cfmj0mqn2q6d4xvgjy9ix1lp6vyf9y0ypl4v6mnvqm5aq9m53cp";};
  }
