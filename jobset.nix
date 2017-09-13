# We define bootstrap_pkgs variable in the jobset definition. This is
# only used to checkout the specified nixpkgs commit.
{ bootstrap_pkgs ? <nixpkgs>
, fetched ? import ./nixpkgs-fetch.nix { nixpkgs = bootstrap_pkgs; }
, _pkgs ? fetched.pkgs
, contrail ? fetched.contrail
}:

let
  pkgs = import _pkgs {};
  lib = import ./lib pkgs;
  ci = import ./ci {inherit pkgs;};
in
  {
    ci.hydraImage = lib.dockerImageBuildProduct ci.hydra;
    ci.pushHydraImage = lib.dockerPushImage ci.hydra;
    contrail = import contrail {inherit pkgs;  pkgs_path = _pkgs;};
  }
