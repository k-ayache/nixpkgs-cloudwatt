pkgs:

{
  mkDebianPackage = drv: pkgs.stdenv.mkDerivation rec {
    name = "${drv.name}.deb";
    phases = [ "unpackPhase" "buildPhase" "installPhase" ];
    buildInputs = [ pkgs.dpkg ];
    src = drv;
    buildPhase = ''
      mkdir DEBIAN
      cat > DEBIAN/control <<EOF
      Package: ${drv.name}
      Architecture: all
      Version: ${drv.version}
      Provides: contrail-vrouter
      EOF
      dpkg-deb --build ./ ../package.deb
    '';
    installPhase = "cp ../package.deb $out";
  };

  debianPackageBuildProduct = pkg:
    let
      name = "debian-package-" + (pkgs.lib.removeSuffix ".deb" pkg.name);
    in
      pkgs.runCommand name {} ''
        mkdir $out
        ln -s ${pkg.out} $out/${pkg.name}
        mkdir $out/nix-support
        echo "file deb ${pkg.out}" > $out/nix-support/hydra-build-products
      '';
}
