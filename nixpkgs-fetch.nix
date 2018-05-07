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
    rev = "0999972a689ddb67f5ab6ec5b7154c8713d2331c";
    sha256 = "1kf80a2b565mkwq1fijscjsr1lqkza9l5bvg2ry778d2c5aa07nw";};
  }
