pkgs:

with import ../deps.nix pkgs;

rec {
  # We use environment variables REGISTRY_URL, REGISTRY_USERNAME,
  # REGISTRY_PASSWORD to specify the url and credentials of the
  # registry.
  dockerPushImage = image:
    let
      imageRef = "${image.imageName}:${builtins.baseNameOf image.out}";
      jobName = with pkgs.lib; "push-" + (removeSuffix ".tar" (removeSuffix ".gz" image.name));
      outputString = "Pushed image " + imageRef;
    in
      pkgs.runCommand jobName {
        buildInputs = with pkgs; [ jq skopeo ];
	impureEnvVars = pkgs.stdenv.lib.fetchers.proxyImpureEnvVars ++
	  [ "REGISTRY_URL" "REGISTRY_USERNAME" "REGISTRY_PASSWORD" ];
	outputHashMode = "flat";
        outputHashAlgo = "sha256";
        outputHash = builtins.hashString "sha256" outputString;
      } ''
      DESTCREDS=""
      CREDS=""
      if [ ! -z $REGISTRY_USERNAME ] && [ ! -z $REGISTRY_USERNAME ]; then
        DESTCREDS="--dest-creds $REGISTRY_USERNAME:$REGISTRY_PASSWORD"
        CREDS="--creds $REGISTRY_USERNAME:$REGISTRY_PASSWORD"
      fi
      if [ -z $REGISTRY_URL ]; then
        REGISTRY_URL="localhost:5000"
      fi

      echo "Ungunzip image (since skopeo doesn't support tgz image)..."
      gzip -d ${image.out} -c > image.tar
      echo "Pushing unzipped image ${image.out} ($(du -hs image.tar | cut -f1)) to registry $REGISTRY_URL/${imageRef} ..."
      skopeo --insecure-policy copy $DESTCREDS --dest-tls-verify=false --dest-cert-dir=/tmp docker-archive:image.tar docker://$REGISTRY_URL/${imageRef}
      skopeo --insecure-policy inspect $CREDS --tls-verify=false --cert-dir=/tmp docker://$REGISTRY_URL/${imageRef}
      echo -n ${outputString} > $out
    '';

  # We want that Hydra generates a link to manually download the image
  dockerImageBuildProduct = image: pkgs.runCommand "${image.name}" {} ''
    mkdir $out
    ln -s ${image.out} $out/image.tar.gz
    mkdir $out/nix-support
    echo "file gzip ${image.out}" > $out/nix-support/hydra-build-products
  '';

  genPerpRcMain = { name, executable, preStartScript?"" }: pkgs.writeTextFile {
    name = "${name}-rc.main";
    executable = true;
    destination = "/etc/perp/${name}/rc.main";
    text = ''
      #!${pkgs.bash}/bin/bash

      exec 2>&1

      TARGET=$1
      SVNAME=$2

      ${preStartScript}

      start() {
        exec ${perp}/usr/sbin/runtool ${executable}
      }

      reset() {
        exit 0
      }

      eval $TARGET "$@"
    '';
  };

  # Build an image where 'command' is started by Perp
  buildImageWithPerp = name: command: pkgs.dockerTools.buildImage {
    inherit name;
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "ubuntu";
      imageTag = "14.04";
      sha256 = "03xg52p31yl69z50ya3cqy0yv160hgsfilhgia7yq520c46xq7m2";
    };
    contents = [
      pkgs.coreutils
      (genPerpRcMain { name=name; executable=command; })
    ];
    config = {
      Cmd = [ "${perp}/usr/sbin/perpd" ];
    };
    extraCommands = ''
      ${pkgs.findutils}/bin/find etc/perp -type d -exec chmod +t {} \;
    '';
  };
}
