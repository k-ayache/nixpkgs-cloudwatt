pkgs:
{
  # This creates a script to run a Ubuntu VM on which extraDebs has
  # been preinstalled.
  # This is mainly used to test genreated Debian packages.
  runUbuntuVmScript = extraDebs:
    let
      kernel = pkgs.vmTools.runInLinuxImage (pkgs.stdenv.mkDerivation {
        name = "kernel-ubuntu1604x86_64";
        diskImage = pkgs.vmTools.diskImageFuns.ubuntu1604x86_64 {
        extraPackages = [ "linux-image-generic" ];};
        memSize = 512;
        phases = "installPhase";
        installPhase = ''
          cp /boot/vmlinuz* $out/vmlinuz
        '';
        });
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
         -kernel ${kernel}/vmlinuz \
         -append "root=/dev/sda console=ttyS0 panic=1" \
         -nographic -no-reboot
      '';
}
