pkgs:

(import ./image.nix pkgs) //
(import ./debian.nix pkgs) //
(import ./tools.nix pkgs) //
{
  images = (import ./images.nix pkgs);
}
