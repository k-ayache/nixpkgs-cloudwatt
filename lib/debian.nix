pkgs:

{
  mkDebianPackage =
  { name
  , contents
  # The script is executed in the package directory context
  , linkScript }:
    pkgs.runCommand name {
    exportReferencesGraph =
      let contentsList = if builtins.isList contents then contents else [ contents ];
      in map (x: [("closure-" + baseNameOf x) x]) contentsList;
    buildInputs = [ pkgs.dpkg ];
  } ''
    NIX_STORE=usr/lib/
    BUILD_DIR=${name}-0.0

    mkdir -p $BUILD_DIR/$NIX_STORE
    paths=$(cat closure-* | grep "^/" | sort | uniq)
    for p in $paths; do
      echo "Copying $p..."
      cp -rp --parents $p $BUILD_DIR/$NIX_STORE
    done

    pushd $BUILD_DIR

    ln -s usr/lib/nix nix

    mkdir DEBIAN
    cat > DEBIAN/control <<EOF
    Package: ${name}
    Architecture: all
    Description: Nixified
    Maintainer: nobody
    Version: 0.0
    EOF

    ${linkScript}

    popd

    dpkg-deb --build $BUILD_DIR package.deb
    cp package.deb $out
  '';

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
