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
    rev = "a4710a367982063aec1317acffe0097d043689a1";
    sha256 = "0488j6g83bxbp3y5wgxx8g2zbx35fx4ljmmfgdy30an6w097ccyh";};
  }
