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
    rev = "c5a2ca31f3feb956f6f495246441a6e9e75d4b70";
    sha256 = "14v0xqmjyav2l1l47n4gplkwmhhb19962m99x5zi9m91l6n4s4gf";};
  }
