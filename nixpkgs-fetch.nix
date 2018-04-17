{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    # Belong to the branch release-18.03
    rev = "32f08fe6c502d04b6350364a626634d425706bb1";
    sha256 = "0fjv0xbwqsajbil9vxlqkqf1iffr5f6cil0cc5wa5xwi7bm1rm9s";};
  contrail = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs-contrail";
    # Belong to the master branch
    rev = "0999972a689ddb67f5ab6ec5b7154c8713d2331c";
    sha256 = "1kf80a2b565mkwq1fijscjsr1lqkza9l5bvg2ry778d2c5aa07nw";};
  }
