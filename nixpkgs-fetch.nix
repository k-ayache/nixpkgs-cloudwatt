{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in bootstrap_pkgs.fetchFromGitHub {
     owner = "nlewo";
     repo = "nixpkgs";
     # Part of the branch release-17.09-cloudwatt
     rev = "e102c3d14ce4d2d13178208710abb85b358f0c18";
     sha256 = "1bacphbasgfl00bvc7wmrlis423g2xpcvrrcswfn5n8p98vw7alm";
   }

