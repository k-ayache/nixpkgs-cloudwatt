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
    rev = "d5f922df2140fd76595cd953545040ad25e62df0";
    sha256 = "1pp6gqqyyw89lvgs42csjqvk9f84p0s6f29s2w1f45xqjjr7l8ky";};
  }
