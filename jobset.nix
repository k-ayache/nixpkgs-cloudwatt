let
  pkgs = import <nixpkgs> {};
in
  { ci = import ./ci {inherit pkgs;}; }
