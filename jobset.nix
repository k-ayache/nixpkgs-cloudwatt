# We define bootstrap_pkgs variable in the jobset definition. This is
# only used to checkout the specified nixpkgs commit.
{ bootstrap_pkgs ? <nixpkgs>
, pkgs ? import (import ./nixpkgs-fetch.nix { nixpkgs = bootstrap_pkgs; }) {} }:

let
  lib = import ./lib pkgs;
  ci = import ./ci {inherit pkgs;};
in
  {
    ci.hydraImage = lib.dockerImageBuildProduct ci.hydra;
    ci.pushHydraImage = lib.dockerPushImage ci.hydra;
  }
