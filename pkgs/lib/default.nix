{ pkgs, cwPkgs }:

let

  callLibs = file: import file { inherit lib pkgs cwPkgs; };

  lib = rec {

    image  = callLibs ./image.nix;
    images = callLibs ./images.nix;
    debian = callLibs ./debian.nix;
    tools = callLibs ./ubuntu-vm.nix;
    fluentd = callLibs ./fluentd.nix;
    trivialBuilders = callLibs ./trivial-builders.nix;

    inherit (image) buildImageWithPerp buildImageWithPerps runDockerComposeStack genPerpRcMain dockerPushImage;

    inherit (debian) mkDebianPackage publishDebianPkg;

    inherit (tools) runUbuntuVmScript;

    inherit (trivialBuilders) writeConsulTemplateYamlFile;
  };

in lib
