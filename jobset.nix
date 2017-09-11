{ pkgs ? import (import ./nixpkgs-fetch.nix) {} }:

let
  lib = import ./lib pkgs;
  ci = import ./ci {inherit pkgs;};
in
  {
    ci.hydraImage = lib.dockerImageBuildProduct ci.hydra;
    ci.pushHydraImage = lib.dockerPushImage ci.hydra;
  }
