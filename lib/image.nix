pkgs:

with import ../deps.nix pkgs;

{
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
