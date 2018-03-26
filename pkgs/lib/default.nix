{ pkgs, cwPkgs }:

(import ./image.nix { inherit pkgs cwPkgs; }) //
(import ./debian.nix pkgs) //
(import ./tools.nix pkgs) //
{
  images = (import ./images.nix pkgs);
}
