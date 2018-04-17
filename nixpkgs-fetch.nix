{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    # Belong to the branch release-18.03-cloudwatt
    rev = "46adfec9f9295ecdd8b10578cd898ba0133d0278";
    sha256 = "0lxys8g7px4ds4892pkvijhsyyh9chzmwck71m4vg6byh27i96v0";};
  contrail = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs-contrail";
    # Belong to the master branch
    rev = "0999972a689ddb67f5ab6ec5b7154c8713d2331c";
    sha256 = "1kf80a2b565mkwq1fijscjsr1lqkza9l5bvg2ry778d2c5aa07nw";};
  }
