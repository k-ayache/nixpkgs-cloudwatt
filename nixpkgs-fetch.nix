{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    # Belong to the branch release-18.03-cloudwatt
    rev = "bccc513396e6ea410cae660e64510f417653bbe4";
    sha256 = "1h8j6h5spal06k4pnvcxmxpi2v6sm9b88snkq25pkdpyyci1zdwi";};
  contrail = bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs-contrail";
    # Belong to the master branch
    rev = "72c1c7b08fe32d1172790fe0e104da9371f18f9c";
    sha256 = "0vkaqa9hi8bgrpasgj5m0qnsbabfp5qdlaf69pfqgbh7x79x9lg0";};
  }
