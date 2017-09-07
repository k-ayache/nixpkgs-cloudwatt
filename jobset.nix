let
  pkgs = import <nixpkgs> {};
  lib = import ./lib pkgs;
  ci = import ./ci {inherit pkgs;};
in
  { ci.hydra = lib.dockerImageBuildProduct ci.hydra; }
