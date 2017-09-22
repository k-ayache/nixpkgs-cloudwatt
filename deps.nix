pkgs:

{
  perp = pkgs.stdenv.mkDerivation {
    name = "perp";
    src = pkgs.fetchurl {
      url = http://b0llix.net/perp/distfiles/perp-2.07.tar.gz;
      sha256 = "05aq8xj9fpgs468dq6iqpkfixhzqm4xzj5l4lyrdh530q4qzw8hj";
    };
    preConfigure = "sed 's~ /usr/~ \${out}/usr/~' -i conf.mk";
  };

  ubuntuKernelHeaders_3_13_0_83_generic = pkgs.stdenv.mkDerivation rec {
    name = "ubuntuKernelHeaders-3.13.0-83-generic";
    phases = [ "unpackPhase" "installPhase" ];
    buildInputs = [ pkgs.dpkg ];
    unpackCmd = "dpkg-deb --extract $curSrc tmp/";
    # Packages url can be foung by browsing https://packages.ubuntu.com/trusty-updates/linux-headers-3.13.0-83-generic
    srcs = [
      (pkgs.fetchurl {
        url = http://fr.archive.ubuntu.com/ubuntu/pool/main/l/linux/linux-headers-3.13.0-83-generic_3.13.0-83.127_amd64.deb;
        sha256 = "f8b5431798c315b7c08be0fb5614c844c38a07c0b6656debc9cc8833400bdd98";
      })
      (pkgs.fetchurl {
        url = http://fr.archive.ubuntu.com/ubuntu/pool/main/l/linux/linux-headers-3.13.0-83_3.13.0-83.127_all.deb;
        sha256 = "7281be1ab2dc3b5627ef8577402fd3e17e0445880d22463e494027f8e904e8fa";
      })
    ];
    installPhase = ''
      mkdir -p $out
      ${pkgs.rsync}/bin/rsync -rl * $out/

      # We patch these scripts since they have been compiled for ubuntu
      for i in recordmcount basic/fixdep mod/modpost; do
        ${pkgs.patchelf}/bin/patchelf --set-interpreter ${pkgs.stdenv.glibc}/lib/ld-linux-x86-64.so.2 $out/usr/src/linux-headers-3.13.0-83-generic/scripts/$i
        ${pkgs.patchelf}/bin/patchelf --set-rpath ${pkgs.stdenv.glibc}/lib $out//usr/src/linux-headers-3.13.0-83-generic/scripts/$i
      done

      ln -sf $out/usr/src/linux-headers-3.13.0-83-generic $out/lib/modules/3.13.0-83-generic/build
    '';
  };
}
