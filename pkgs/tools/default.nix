{ debianPackages, lib }:

{
  # This build an Ubuntu vm where Debian packages are
  # preinstalled. This is used to easily try generated Debian
  # packages.
  installDebianPackages = lib.runUbuntuVmScript [
    debianPackages.contrailVrouterUbuntu_3_13_0_83_generic
    debianPackages.contrailVrouterUserland
  ];
}
