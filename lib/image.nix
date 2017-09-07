pkgs:

with import ../deps.nix pkgs;

{
  dockerPushImage = { image, url ? "localhost:5000", username ? null, password ? null }:
    let
      imageRef = "${image.imageName}:${image.imageTag}";
      destCreds = if (username != null && password != null) then "--dest-creds ${username}:${password}" else "";
      creds     = if (username != null && password != null) then "--creds ${username}:${password}" else "";
      jobName = with pkgs.lib; "push-" + (removeSuffix ".tar" (removeSuffix ".gz" image.name));
    in
      pkgs.runCommand jobName {
        buildInputs = with pkgs; [ jq skopeo ];
      } ''
      echo "Ungunzip image (since skopeo doesn't support tgz image)..."
      gzip -d ${image.out} -c > image.tar
      echo "Pushing unzipped image ${image.out} ($(du -hs image.tar | cut -f1)) to registry ${url}/${imageRef} ..."
      skopeo --insecure-policy copy ${destCreds} --dest-tls-verify=false --dest-cert-dir=/tmp docker-archive:image.tar docker://${url}/${imageRef} > skipeo.log
      skopeo --insecure-policy inspect ${creds} --tls-verify=false --cert-dir=/tmp docker://${url}/${imageRef} > $out
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
}
