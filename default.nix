{ bootstrap_pkgs ? import <nixpkgs> {}
, pkgs_path ? bootstrap_pkgs.fetchFromGitHub {
    owner = "nlewo";
    repo = "nixpkgs";
    rev = "638de38c58f1268c1c0f70d1e0c6a153152f0d66";
    sha256 = "08a7sla6zpg5vbfcza8jr9cn9163qgm2384lrnx66ii6ykdxrq7q";
  }
, pkgs ? import pkgs_path {}
}:

{ ci.hydra = import ./ci {inherit pkgs;}; }
