{ pkgs, ... }:

let
  # This is used to build a vm to test packages
  ubuntuKernelImage_3_13_0_83_generic = pkgs.stdenv.mkDerivation rec {
    name = "ubuntuImageHeaders-3.13.0-83-generic";
    phases = [ "unpackPhase" "installPhase" ];
    buildInputs = [ pkgs.dpkg ];
    unpackCmd = "dpkg-deb --extract $curSrc tmp/";
    src = pkgs.fetchurl {
      url = http://fr.archive.ubuntu.com/ubuntu/pool/main/l/linux/linux-image-3.13.0-83-generic_3.13.0-83.127_amd64.deb;
      sha256 = "1gmg99a5ipdi7fjcna3wf8as58p84p3l9wl89d7b3lgm26qvrzg2";
    };
    installPhase = ''
      cp boot/vmlinuz* $out
    '';
  };
in
{
  # This creates a script to run a Ubuntu VM on which extraDebs has
  # been preinstalled.
  # This is mainly used to test genreated Debian packages.
  runUbuntuVmScript = extraDebs:
    let
      image = pkgs.vmTools.diskImageFuns.ubuntu1604x86_64 {
        extraDebs = extraDebs;
      };
    in pkgs.writeScript "run-ubuntu-script" ''
      rm -rf /tmp/run-ubuntu-vm.tmp
      mkdir /tmp/run-ubuntu-vm.tmp
      echo "Copying image ${image}/disk-image.qcow2 to /tmp/run-ubuntu-vm.tmp/ ..."
      cp ${image}/disk-image.qcow2 /tmp/run-ubuntu-vm.tmp/
      chmod a+rw -R /tmp/run-ubuntu-vm.tmp
      ${pkgs.qemu}/bin/qemu-kvm -hda /tmp/run-ubuntu-vm.tmp/disk-image.qcow2 \
         -kernel ${ubuntuKernelImage_3_13_0_83_generic} \
         -append "root=/dev/sda console=ttyS0 panic=1" \
         -nographic -no-reboot
      '';
}
