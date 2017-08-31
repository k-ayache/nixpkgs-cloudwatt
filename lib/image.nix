pkgs:

with import ../deps.nix pkgs;

rec {
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
