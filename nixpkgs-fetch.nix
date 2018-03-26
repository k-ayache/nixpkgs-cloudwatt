{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs";
    # Belong to the branch release-17.09-cloudwatt
    rev = "9d080dba21ec31cc824ad896dd66bb1b9c8108ac";
    sha256 = "14kc5dgjx1mpmwr3ha9gpw24mxk6c80x011q5aj9p6a4clj4h8ac";};
  contrail = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs-contrail";
    # Belong to the master branch
    rev = "9c06f11b9bbd9c2c847d0658a7d4025e05320e0d";
    sha256 = "0y7asv7vj5hmg6r65ybbknlx153wy81pwz8xp60wi9pwhfzdfs86";};
  }
