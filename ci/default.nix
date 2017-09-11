{pkgs ? import <nixpkgs> {}}:

with import ../lib/image.nix pkgs;
with import ../deps.nix pkgs;

let hydraServerCmd = "${pkgs.hydra}/bin/hydra-server hydra-server -f -h 0.0.0.0 -p 3000 --max_spare_servers 5 --max_servers 25 --max_requests 100 -d";
    hydraQueueRunnerCmd = "${pkgs.hydra}/bin/hydra-queue-runner -vvvvv --option build-use-substitutes true";
    hydraEvaluator = "${pkgs.hydra}/bin/hydra-evaluator -vvvvv";

    hydraBaseDir = "var/lib/hydra/";

    hydraConf = pkgs.writeText "hydra.conf" ''
      using_frontend_proxy 1
      base_uri http://example.com
      notification_sender hydra@example.com
      max_servers 25
      gc_roots_dir /nix/var/nix/gcroots/hydra
      max_output_size = 4294967296
      use-substitutes = 1
    '';

    # We need nscd to workaround the bug https://github.com/NixOS/nix/issues/1536
    # Once it is fixed, remove nscd
    nscdConf = pkgs.writeText "nscd.conf" ''
      server-user             root
      threads                 1
      paranoia                no
      debug-level             0

      enable-cache            hosts           yes
      positive-time-to-live   hosts           600
      negative-time-to-live   hosts           5
      suggested-size          hosts           211
      check-files             hosts           yes
      persistent              hosts           no
      shared                  hosts           yes
    '';
    nscdInit = ''
      mkdir -p var/db/nscd
      mkdir -p var/run/nscd
    '';

    nixConf = pkgs.writeText "nix.conf" ''
      build-users-group = nixbld
      build-max-jobs = 1
      build-cores = 1
      build-use-sandbox = false
      trusted-binary-caches =
      auto-optimise-store = false
      binary-caches = https://cache.nixos.org/

      trusted-users = *
      allowed-users = *
      gc-keep-outputs = true
      gc-keep-derivations = true

      # The default (`true') slows Nix down a lot since the build farm
      # has so many GC roots.
      gc-check-reachability = false

      auto-optimise-store = true
    '';

    containerInit = ''
      mkdir -p etc
      chmod 0755 etc
      echo 'hosts:     files dns' > etc/nsswitch.conf

      mkdir -p etc/ssl/certs
      ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt etc/ssl/certs/ca-certificates.crt
    '';
    
    hydraInit = ''
      mkdir -p nix/var/nix/gcroots/hydra
      mkdir -p var/lib/hydra/

      mkdir -p ${hydraBaseDir}
      chmod 0750 ${hydraBaseDir}

      mkdir -m 0700 -p ${hydraBaseDir}/www
      mkdir -m 0700 -p ${hydraBaseDir}/queue-runner
      mkdir -m 0750 -p ${hydraBaseDir}/build-logs

      cp ${hydraConf} var/lib/hydra/hydra.conf

      mkdir -p nix-cache
    '';

    nixInit = ''
      mkdir {tmp,root}
      chmod 777 tmp
      echo "root:x:0:0::/root:/bin/bash" >> etc/passwd
      echo "nixbld:x:30000:nixbld1,nixbld2,nixbld3,nixbld4,nixbld5,nixbld6,nixbld7,nixbld8,nixbld9,nixbld10,nixbld11,nixbld12,nixbld13,nixbld14,nixbld15,nixbld16,nixbld17,nixbld18,nixbld19,nixbld20,nixbld21,nixbld22,nixbld23,nixbld24,nixbld25,nixbld26,nixbld27,nixbld28,nixbld29,nixbld30" >> etc/group
      for i in $(seq 1 30); do echo "nixbld$i:x:$((30000 + $i)):30000:::" >> etc/passwd; done

      mkdir -p etc/nix
      ln -s ${nixConf} etc/nix/nix.conf
    '';

    # This could be avoided by patching in contrail build itself
    contrailBuildInit = ''
      mkdir -p usr/bin
      ln -s ${pkgs.coreutils}/bin/env usr/bin/env
    '';

    perpInit = ''
      ${pkgs.findutils}/bin/find etc/perp -type d -exec chmod +t {} \;
    '';
    
    # This is executed at container runtime
    hydraPreStart = pkgs.writeScript "hydraPreStart" ''
      if [ "$BINARY_CACHE_KEY_SECRET" != "" ]; then
        echo $BINARY_CACHE_KEY_SECRET > /var/lib/hydra/secret
	chmod 440 /var/lib/hydra/secret
        cp ${hydraConf} /var/lib/hydra/hydra.conf
	echo 'binary_cache_secret_key_file = /var/lib/hydra/secret' >> /var/lib/hydra/hydra.conf
      fi

      if [ "$BINARY_CACHE_KEY_PUBLIC" != "" ]; then
        cp ${nixConf} /etc/nix/nix.conf
	echo "binary-cache-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= $BINARY_CACHE_KEY_PUBLIC" >> /etc/nix/nix.conf
	echo "signed-binary-caches = *" >> /etc/nix/nix.conf
      fi

      echo "localhost x86_64-linux - $MAX_JOBS 1 kvm,nixos-test,big-parallel" > /etc/nix/machines

      if [ -i /dev/kvm ]; then
        chgrp nixbld /dev/kvm
      fi
    '';

in
{
hydra = pkgs.dockerTools.buildImageWithNixDb rec {
    name = "hydra";
    contents = [
      pkgs.hydra
      pkgs.nix pkgs.eject # eject provides 'more' which is required by nix-store

      # To manually initialize the database
      pkgs.postgresql93

      # Interactive mode
      pkgs.coreutils pkgs.bashInteractive pkgs.curl

      (genPerpRcMain {name = "hydra-server"; executable = hydraServerCmd; preStartScript = hydraPreStart; })
      (genPerpRcMain {name = "hydra-queue-runner"; executable = hydraQueueRunnerCmd; })
      (genPerpRcMain {name = "hydra-evaluator"; executable = hydraEvaluator; })
      (genPerpRcMain {name = "nscd"; executable = "${pkgs.glibc.bin}/sbin/nscd -f ${nscdConf} -F"; })
    ];
    extraCommands = ''
      # There is a bug in the docker builder
      chmod a+w ../layer 
      ''
      + containerInit + nixInit + hydraInit + nscdInit + perpInit + contrailBuildInit;

    config = {
      Cmd = [ "${perp}/usr/sbin/perpd" ];
      Env = [
        "HYDRA_DATA=/${hydraBaseDir}"
        "HYDRA_CONFIG=/${hydraBaseDir}/hydra.conf"
	"HYDRA_DBI=dbi:Pg:dbname=hydra;host=postgres;user=hydra;"
	"BINARY_CACHE_KEY_SECRET="
	"BINARY_CACHE_KEY_PUBLIC="
	"MAX_JOBS=1"
      ];
    };
  };
}
