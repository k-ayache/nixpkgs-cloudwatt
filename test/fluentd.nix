{ pkgs
, pkgs_path ? <nixpkgs>
, cwPkgs
, lib
}:

with import (pkgs_path + /nixos/lib/testing.nix) { system = builtins.currentSystem; };

let

  fluentdConf = pkgs.writeTextFile {
    name = "fluentd.conf";
    text = ''
      <source>
        @type forward
        port 24224
      </source>
      <match **>
        @type stdout
      </match>
    '';
  };

  stdoutSvc = pkgs.writeShellScriptBin "stdout-svc" ''
    while true
    do
      echo "stdout-svc"
      sleep 1
    done
  '';

  stdoutImage = lib.buildImageWithPerps {
    name = "stdout-image";
    fromImage = lib.images.kubernetesBaseImage;
    services = [
      {
        name = "stdout-svc";
        command = "${stdoutSvc}/bin/stdout-svc";
        fluentd = {
          source = {
            type = "stdout";
          };
        };
      }
    ];
  };

  runStack = lib.runDockerComposeStack {
    version = "2";
    services = {
      stdoutSvc = {
        image = builtins.baseNameOf stdoutImage;
        network_mode = "host";
      };
    };
  };

  machine = { config, ... }: {
    config = rec {
      services.openssh.enable = true;
      services.openssh.permitRootLogin = "yes";
      users.extraUsers.root.password = "root";

      virtualisation = { diskSize = 4960; memorySize = 1024; };
      virtualisation.docker.enable = true;

      networking.hosts = {
        "127.0.0.1" = [ "fluentd.localdomain" ];
      };

      systemd.services.fluentd = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        script = "${cwPkgs.fluentdCw}/bin/fluentd --no-supervisor -c ${fluentdConf}";
      };

    };
  };

  testScript = ''
    $machine->waitForUnit("network.target");
    $machine->waitForUnit("sockets.target");
    $machine->waitForUnit("fluentd.service");
    $machine->succeed("${runStack}");
    $machine->waitUntilSucceeds("journalctl --unit fluentd --no-pager | grep stdout-svc");
  '';
in
  makeTest { name = "fluentd"; nodes = { inherit machine; }; testScript = testScript; }
    // { driverDockerCompose = runStack; }
