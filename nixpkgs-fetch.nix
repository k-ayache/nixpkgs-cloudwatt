{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs-channels";
    # Belong to the branch release-17.09-cloudwatt
    rev = "66b4de79e3841530e6d9c6baf98702aa1f7124e4";
    sha256 = "1l3lwi944hnxka0nfq9a1g86xhc0b8hzqr2fm6cvds33gj26l0g4";};
  contrail = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs-contrail";
    # Belong to the master branch
    rev = "556de030c65f9b74f97ccc0e5d81f90f3b06c74a";
    sha256 = "0lj06y6h702r3hjz0hnvn54rs7nl729j1w05ai4c0z5rqy4bvz1d";};
  }
