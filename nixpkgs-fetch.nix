{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs";
    # Belong to the branch release-17.09-cloudwatt
    rev = "cb5ac615101c5ef346a88648f918685f39f335d8";
    sha256 = "0lrn1vvbli82zkcq32dkkj56b1l008bmpw2zyhmsw85ajqw8imab";};
  contrail = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs-contrail";
    # Belong to the master branch
    rev = "29ca558d4fcb331ff482cfa3b0124cba59ff86dc";
    sha256 = "12mpbzlg9pc211axsa2sd99z115nk1k1zb3sw091gmd82ck6jzma";};
  }
