{ pkgs, ... }:

let
  control = name: version: description:
    pkgs.writeText "control-${name}" ''
      Package: ${name}
      Architecture: all
      Description: ${description}
      Maintainer: nobody
      Version: ${version}
    '';

in
rec {
  mkDebianPackage =
  { name
  # All Nix dependencies of contents are copied to the $NIX_STORE
  # (/var/opt/) directory in the Debian package and a link is created
  # from $NIX_STORE to /nix/store.
  , contents ? []
  # The script is executed in the package directory context
  , script
  , version
  # The repository name of this package. Note this is only used to
  # publish packages to Aptly. By default it is the package name.
  , repository ? name
  , description
  # A list of derivations that are copiyed to the DEBIAN
  # directory. This can be used to add postinst scripts for instance.
  , maintainerScripts ? []
  }:
    pkgs.runCommand "${name}-${version}.deb" {
    exportReferencesGraph =
      map (x: [("closure-" + baseNameOf x) x]) contents;
    buildInputs = [ pkgs.dpkg ];
    inherit version repository;
  } (''
      BUILD_DIR=${name}-0.0
      mkdir -p $BUILD_DIR
    '' + pkgs.lib.optionalString (contents != []) ''
      NIX_STORE=var/opt/

      mkdir -p $BUILD_DIR/$NIX_STORE
      paths=$(cat closure-* | grep "^/" | sort | uniq)
      for p in $paths; do
        echo "Copying $p..."
        cp -rp --parents $p $BUILD_DIR/$NIX_STORE
      done

      ln -s $NIX_STORE/nix $BUILD_DIR/nix
    '' + ''
      pushd $BUILD_DIR

      mkdir DEBIAN
      cp ${control name version description} DEBIAN/control

    '' + pkgs.lib.concatMapStringsSep "\n" (x: "cp ${x} DEBIAN/${x.name}") maintainerScripts
    + ''

      ${script}

      popd

      # FIXME: the -Z option is a workaround for https://bugs.launchpad.net/ubuntu/+source/dpkg/+bug/1730627
      # -Z could be removed when dpkg 1.17.5ubuntu5.8 is deployed.
      dpkg-deb --build -Z gzip $BUILD_DIR $out
    '');

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
    let outputString = "${package.name} published to ${url} in repository ${package.repository}";
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
           debian-package-publish.sh -d trusty -r ${package.repository}-${package.version} packages
           echo -n ${outputString} > $out
         '';
}
