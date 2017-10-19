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
    rev = "ff7a7895941de5c51eb078dfe87b5edec411f547";
    sha256 = "1829jlg4cdy8qmjskqjy19sd2si5ggy1rp6nhzrixp1kksbpn41h";};
  }
