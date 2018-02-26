{pkgs, lib, perp, makeWrapper, curl, stdenv, waitFor }:

with lib;

let hydraServerCmd = "${pkgs.hydra}/bin/hydra-server hydra-server -f -h 0.0.0.0 -p 3000 --max_spare_servers 5 --max_servers 25 --max_requests 100 -d";
    hydraQueueRunnerCmd = "${pkgs.hydra}/bin/hydra-queue-runner -vvvvv --option build-use-substitutes true";
    hydraEvaluator = "${pkgs.hydra}/bin/hydra-evaluator -vvvvv";

    binaryCacheUri = "file:///nix-cache/";
    hydraBaseDir = "var/lib/hydra/";
    hydraStatefulDir = "hydra";

    createDeclarativeProjectScript = pkgs.stdenv.mkDerivation {
      name = "create-declarative-project";
      unpackPhase = ":";
      buildInputs = [ makeWrapper ];
      installPhase = "install -m755 -D ${./create-declarative-project.sh} $out/bin/create-declarative-project";
      postFixup = ''wrapProgram "$out/bin/create-declarative-project" --prefix PATH ":" ${stdenv.lib.makeBinPath [ curl ]}'';
    };

    declarativeProjectName = "create-declarative-project";

    hydraEvalScript = pkgs.stdenv.mkDerivation {
      name = "hydra-eval-script";
      unpackPhase = ":";
      buildInputs = [ makeWrapper ];
      installPhase = "install -m755 -D ${./hydra-eval.sh} $out/bin/hydra-eval";
      postFixup = ''wrapProgram "$out/bin/hydra-eval" --set NO_PROXY localhost --prefix PATH ":" ${stdenv.lib.makeBinPath [ curl ]}'';
    };

    hydraConf = pkgs.writeText "hydra.conf" ''
      using_frontend_proxy 1
      base_uri http://example.com
      notification_sender hydra@example.com
      max_servers 25
      gc_roots_dir /nix/var/nix/gcroots/hydra
      max_output_size = 4294967296
      store_uri = ${binaryCacheUri}
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
      binary-caches = https://cache.nixos.org/ ${binaryCacheUri}

      trusted-users = *
      allowed-users = *
      gc-keep-outputs = true
      gc-keep-derivations = true

      # The default (`true') slows Nix down a lot since the build farm
      # has so many GC roots.
      gc-check-reachability = false

      auto-optimise-store = true
    '';

    nginxConf = pkgs.writeText "nginx.conf" ''
      user root root;
      daemon off;
      error_log /dev/stdout info;
      pid /tmp/nginx.pid;
      events {}
      http {
        client_body_temp_path /tmp;
        proxy_temp_path /tmp;
        fastcgi_temp_path /tmp;
        uwsgi_temp_path /tmp;
        scgi_temp_path /tmp;
        access_log /dev/stdout;
        server {
            listen 80;
            root /nix-cache;
        }
      }
    '';

    containerInit = ''
      mkdir -p etc
      chmod 0755 etc
      echo 'hosts:     files dns' > etc/nsswitch.conf

      mkdir -p etc/ssl/certs
      ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt etc/ssl/certs/ca-certificates.crt
    '';
    
    hydraInit = ''
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

      echo "root:x:0:" >> etc/group

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
      # We fix missing hash and size otherwise hydra-queue-runner gets
      # lot of troubles... (segfaults, freezes...)
      # This can be removed with the release 18.03
      nix-store --verify --check-contents

      # If Hydra credentials are provided, we create the admin account
      if [ "$POSTGRES_PASSWORD" == "" ]; then
        echo "You must set the POSTGRES_PASSWORD environment variable. Exiting."
        exit 1
      fi
      echo "*:*:*:*:$POSTGRES_PASSWORD" > /root/.pgpass
      chmod 600 /root/.pgpass

      # Hydra database schema initialisation
      while ! hydra-init; do
        echo "Failed to connect to the database. Retrying..."
        sleep 1
      done

      # If Hydra credentials are provided, we create the admin account
      if [ "$HYDRA_ADMIN_USERNAME" != "" ] && [ "$HYDRA_ADMIN_PASSWORD" != "" ]; then
        echo "Creating $HYDRA_ADMIN_USERNAME account with admin role..."
        hydra-create-user $HYDRA_ADMIN_USERNAME --role admin --password $HYDRA_ADMIN_PASSWORD
      fi

      # We replace build logs dir by a link to keep them.
      # Build logs should be send to an object storage instead...
      mkdir -p /${hydraStatefulDir}/build-logs
      mkdir -p /${hydraStatefulDir}/gcroots/hydra
      ln -s /${hydraStatefulDir}/gcroots/hydra /nix/var/nix/gcroots/hydra

      rmdir /${hydraBaseDir}/build-logs
      ln -sf /${hydraStatefulDir}/build-logs /${hydraBaseDir}/build-logs

      if [ "$BINARY_CACHE_KEY_SECRET" != "" ]; then
        echo $BINARY_CACHE_KEY_SECRET > /var/lib/hydra/secret
        chmod 440 /var/lib/hydra/secret
        cp ${hydraConf} /var/lib/hydra/hydra.conf
        # This could be deprecated since we specify the binary cache in the store_uri variable
        echo 'binary_cache_secret_key_file = /var/lib/hydra/secret' >> /var/lib/hydra/hydra.conf
        # This is to sign the generated binary cache
        sed -i 's|store_uri = ${binaryCacheUri}|store_uri = ${binaryCacheUri}?secret-key=/var/lib/hydra/secret|' /var/lib/hydra/hydra.conf
      fi

      if [ "$BINARY_CACHE_KEY_PUBLIC" != "" ]; then
        cp ${nixConf} /etc/nix/nix.conf
        echo "binary-cache-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= $BINARY_CACHE_KEY_PUBLIC" >> /etc/nix/nix.conf
        echo "signed-binary-caches = *" >> /etc/nix/nix.conf
      fi

      echo "localhost x86_64-linux - $MAX_JOBS 1 kvm,nixos-test,big-parallel" > /etc/nix/machines

      if [ -e /dev/kvm ]; then
        chgrp nixbld /dev/kvm
        chmod g+rw /dev/kvm
      fi
    '';

    entrypoint = pkgs.writeScript "entrypoint" ''
      #!${pkgs.bash}/bin/bash
      set -e
      ${hydraPreStart}
      exec ${perp}/usr/sbin/perpd
    '';

in {
  hydraImage = pkgs.dockerTools.buildImageWithNixDb rec {
    name = "hydra/master";
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "r.cwpriv.net/kubernetes/base";
      imageTag = "16.04-c6e9c969951cf94b";
      sha256 = "0gksw7l0mbdhmjvb0mvb48h5ay9qr7sqsxq4hs3cfla9kn73l5cd";
    };

    contents = [
      pkgs.hydra
      pkgs.nix
      hydraEvalScript

      # To manually initialize the database
      pkgs.postgresql93

      (genPerpRcMain {name = "hydra-server"; command = hydraServerCmd; })
      (genPerpRcMain {name = "hydra-queue-runner"; command = hydraQueueRunnerCmd; })
      (genPerpRcMain {name = "hydra-evaluator"; command = hydraEvaluator; })
      (genPerpRcMain {name = "nscd"; command = "${pkgs.glibc.bin}/sbin/nscd -f ${nscdConf} -F"; })
      (genPerpRcMain {name = "nginx"; command = "${pkgs.nginx}/bin/nginx -c ${nginxConf}"; })
      (genPerpRcMain {
        name = declarativeProjectName;
        preStartScript = "export NO_PROXY=localhost";
        command = "${waitFor}/bin/wait-for localhost:3000 -- ${createDeclarativeProjectScript}/bin/create-declarative-project";
        oneshot = true;
      })
    ];
    extraCommands = ''
      # There is a bug in the docker builder
      chmod a+w ../layer 
      ''
      + containerInit + nixInit + hydraInit + nscdInit + perpInit + contrailBuildInit;

    config = {
      Cmd = [ "${entrypoint}" ];
      Env = [
        # hydra-queue-runner fails to start without this
        "LOGNAME=none"

        "HYDRA_DATA=/${hydraBaseDir}"
        "HYDRA_CONFIG=/${hydraBaseDir}/hydra.conf"
        "HYDRA_DBI=dbi:Pg:dbname=hydra;host=postgres;user=hydra;"
        "BINARY_CACHE_KEY_SECRET="
        "BINARY_CACHE_KEY_PUBLIC="
        "MAX_JOBS=1"
        "HYDRA_ADMIN_USERNAME="
        "HYDRA_ADMIN_PASSWORD="
        "POSTGRES_PASSWORD="
        "DECL_PROJECT_NAME="
        "DECL_FILE="
        "DECL_TYPE="
        "DECL_VALUE="
      ];
    };
  };
}
