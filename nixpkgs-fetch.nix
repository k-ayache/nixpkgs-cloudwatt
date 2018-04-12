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
    rev = "28b300256394d4fae7f9bf278e6626137e23c891";
    sha256 = "1lr4nyz8gj0l9l72gly4m6xzx5wliypby4ik45085ghraniydp34";};
  }
