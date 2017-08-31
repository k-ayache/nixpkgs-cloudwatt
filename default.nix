{ bootstrap_pkgs ? import <nixpkgs> {}
, pkgs_path ? bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs";
    rev = "1e8c43bb98d8f85c3ace4e73745e8853b0abd0e6";
    sha256 = "01a0wmddm8j07k4g0lj2xwmpnr0fr4a7ssx56kldq98k82iac964";
  }
, pkgs ? import pkgs_path {}
}:

{ ci.hydra = import ./ci {inherit pkgs;}; }
