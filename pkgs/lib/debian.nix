pkgs:

rec {
  mkDebianPackage =
  { name
  , contents
  # The script is executed in the package directory context
  , linkScript
  , version
  , description
  }:
    pkgs.runCommand "${name}-${version}.deb" {
    exportReferencesGraph =
      let contentsList = if builtins.isList contents then contents else [ contents ];
      in map (x: [("closure-" + baseNameOf x) x]) contentsList;
    buildInputs = [ pkgs.dpkg ];
    inherit version;
  } ''
    NIX_STORE=var/opt/
    BUILD_DIR=${name}-0.0

    mkdir -p $BUILD_DIR/$NIX_STORE
    paths=$(cat closure-* | grep "^/" | sort | uniq)
    for p in $paths; do
      echo "Copying $p..."
      cp -rp --parents $p $BUILD_DIR/$NIX_STORE
    done

    pushd $BUILD_DIR

    ln -s $NIX_STORE/nix nix

    mkdir DEBIAN
    cat > DEBIAN/control <<EOF
    Package: ${name}
    Architecture: all
    Description: ${description}
    Maintainer: nobody
    Version: ${version}
    EOF

    ${linkScript}

    popd

    dpkg-deb --build $BUILD_DIR package.deb
    cp package.deb $out
  '';

  debianPackagePublish = pkgs.stdenv.mkDerivation rec {
    name = "debian-package-publish.sh";
    src = ./debian-package-publish.sh;
    phases = [ "unpackPhase" "patchPhase" "installPhase" "fixupPhase" ];
    unpackCmd = "mkdir build; cp $curSrc ./build/debian-package-publish.sh";
    patchPhase = ''
      substituteInPlace debian-package-publish.sh --replace 'uuidgen' '${pkgs.utillinux}/bin/uuidgen'
      substituteInPlace debian-package-publish.sh --replace 'curl' '${pkgs.curl}/bin/curl'
    '';
    installPhase = ''
      mkdir -p $out/bin; cp debian-package-publish.sh $out/bin/debian-package-publish.sh
    '';
  };

  publishDebianPkg = url: package: unsetProxy:
    let outputString = "${package.name} published to ${url}";
    in pkgs.runCommand "publish-${package.name}"
         {
           buildInputs = [ debianPackagePublish ];
           outputHashMode = "flat";
           outputHashAlgo = "sha256";
           outputHash = builtins.hashString "sha256" outputString;
           impureEnvVars = pkgs.lib.optionals (!unsetProxy) pkgs.stdenv.lib.fetchers.proxyImpureEnvVars;
         } ''
           export APTLY_URL=${url}
           mkdir packages
           ln -s ${package} packages/${package.name}
           echo "Publishing ${package.name} to $APTLY_URL ..."
           debian-package-publish.sh -d trusty -r contrail-${package.version} packages
           echo -n ${outputString} > $out
         '';
}
