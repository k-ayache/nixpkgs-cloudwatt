pkgs:

let
  # Packages urls can be foung by browsing https://packages.ubuntu.com/trusty-updates/linux-headers-3.13.0-83-generic
  # We need the fetch two packages to have both the kernel headers and the kernel configuration.
  ubuntuKernelHeaders = version: srcs: pkgs.stdenv.mkDerivation rec {
    inherit version srcs;
    pname = "ubuntu-kernel-headers";
    name = "${pname}-${version}";
    phases = [ "unpackPhase" "installPhase" ];
    buildInputs = [ pkgs.dpkg ];
    unpackCmd = "dpkg-deb --extract $curSrc tmp/";
    installPhase = ''
      mkdir -p $out
      ${pkgs.rsync}/bin/rsync -rl * $out/

      # We patch these scripts since they have been compiled for ubuntu
      for i in recordmcount basic/fixdep mod/modpost; do
        ${pkgs.patchelf}/bin/patchelf --set-interpreter ${pkgs.stdenv.glibc}/lib/ld-linux-x86-64.so.2 $out/usr/src/linux-headers-${version}/scripts/$i
        ${pkgs.patchelf}/bin/patchelf --set-rpath ${pkgs.stdenv.glibc}/lib $out//usr/src/linux-headers-${version}/scripts/$i
      done

      ln -sf $out/usr/src/linux-headers-${version} $out/lib/modules/${version}/build
    '';
  };
in
{
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

  ubuntuKernelHeaders_3_13_0_83_generic = ubuntuKernelHeaders "3.13.0-83-generic" [
    (pkgs.fetchurl {
      url = http://fr.archive.ubuntu.com/ubuntu/pool/main/l/linux/linux-headers-3.13.0-83-generic_3.13.0-83.127_amd64.deb;
      sha256 = "f8b5431798c315b7c08be0fb5614c844c38a07c0b6656debc9cc8833400bdd98";
    })
    (pkgs.fetchurl {
      url = http://fr.archive.ubuntu.com/ubuntu/pool/main/l/linux/linux-headers-3.13.0-83_3.13.0-83.127_all.deb;
      sha256 = "7281be1ab2dc3b5627ef8577402fd3e17e0445880d22463e494027f8e904e8fa";
    })
  ];

  ubuntuKernelHeaders_3_13_0_112_generic = ubuntuKernelHeaders "3.13.0-112-generic" [
    (pkgs.fetchurl {
      url = http://fr.archive.ubuntu.com/ubuntu/pool/main/l/linux/linux-headers-3.13.0-112-generic_3.13.0-112.159_amd64.deb;
      sha256 = "0kjj6zkr8yh79haj7xqdqndwq2rhcvs53wzkgfa666q939dh4dr0";
    })
    (pkgs.fetchurl {
      url = http://fr.archive.ubuntu.com/ubuntu/pool/main/l/linux/linux-headers-3.13.0-112_3.13.0-112.159_all.deb;
      sha256 = "1irx346ifqbirz4pfncpz1spynhy3hmy1y3sfmva339vx6a224y9";
    })
  ];

  ubuntuKernelHeaders_3_13_0_125_generic = ubuntuKernelHeaders "3.13.0-125-generic" [
    (pkgs.fetchurl {
      url = http://fr.archive.ubuntu.com/ubuntu/pool/main/l/linux/linux-headers-3.13.0-125-generic_3.13.0-125.174_amd64.deb;
      sha256 = "0s231qkf5bjdnaj103xxv1wwspy4vlgbsgzk93254ixqvsjh5hbr";
    })
    (pkgs.fetchurl {
      url = http://fr.archive.ubuntu.com/ubuntu/pool/main/l/linux/linux-headers-3.13.0-125_3.13.0-125.174_all.deb;
      sha256 = "1hbb6z1i5xjx68nssxm90jr6h142n8cphbi8z688cz05zrnzlk60";
    })
  ];

  ubuntuKernelHeaders_4_4_0_101_generic = ubuntuKernelHeaders "4.4.0-101-generic" [
    (pkgs.fetchurl {
      url = http://fr.archive.ubuntu.com/ubuntu/pool/main/l/linux/linux-headers-4.4.0-101-generic_4.4.0-101.124_amd64.deb;
      sha256 = "0sm03g37ndp5hyxkk8sszy5jkwcp1css2nlpyw4jsw57kwncrmx6";
    })
    (pkgs.fetchurl {
      url = http://fr.archive.ubuntu.com/ubuntu/pool/main/l/linux/linux-headers-4.4.0-101_4.4.0-101.124_all.deb;
      sha256 = "1zxnwm1a4y9lfszl8idh0kcirwyy78ml4s54kb1hxfm88kllhbcc";
    })
  ];
}
