{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in bootstrap_pkgs.fetchFromGitHub {
     owner = "nlewo";
     repo = "nixpkgs";
     rev = "afbf69691ead9c423fd026f2a80933973b22a774";
     sha256 = "1xb4yayrzmplr25npwj94l56mwif9xy8acc5z8i849yvrrnp0zfa";
   }

