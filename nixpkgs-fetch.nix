{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    # Belong to the branch release-18.03
    rev = "f952058df732ddccc323f3c56171da6085013299";
    sha256 = "0jlpwd10ir7c10fqg0njis2dy1qdwg7xksy6y7017hjv2pwalzb3";};
  contrail = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs-contrail";
    # Belong to the master branch
    rev = "043fb365260c178622c0f18cf84b7ad7290e1a8b";
    sha256 = "0cfmj0mqn2q6d4xvgjy9ix1lp6vyf9y0ypl4v6mnvqm5aq9m53cp";};
  }
