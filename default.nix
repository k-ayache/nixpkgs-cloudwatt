{ fetched ? import ./nixpkgs-fetch.nix {}
, nixpkgs ? fetched.pkgs
, contrail ? fetched.contrail
}:


let pkgs = import nixpkgs {};
in
  { ci.hydra = import ./ci {inherit pkgs;};
    contrail = import contrail { inherit pkgs; };
  }
