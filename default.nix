{ nixpkgs ? import ./nixpkgs-fetch.nix }:

let pkgs = import nixpkgs {};
in
  { ci.hydra = import ./ci {inherit pkgs;};
  }
