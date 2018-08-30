{ pkgs
, fluentdCw
, lib
}:

with import (pkgs.path + /nixos/lib/testing.nix) { system = builtins.currentSystem; };

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

  syslogSvc = pkgs.writeShellScriptBin "syslog-svc" ''
    while true
    do
      echo "<133>$0[$$]: syslog-svc" | nc -w1 -u localhost 1234
      sleep 1
    done
  '';

  testImage = lib.buildImageWithPerps {
    name = "test-image";
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
      {
        name = "syslog-svc";
        command = "${syslogSvc}/bin/syslog-svc";
        fluentd = {
          source = {
            type = "syslog";
            port = 1234;
            format = "none";
          };
        };
      }
    ];
  };

  runStack = lib.runDockerComposeStack {
    version = "2";
    services = {
      test = {
        image = builtins.baseNameOf testImage;
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
        script = "${fluentdCw}/bin/fluentd --no-supervisor -c ${fluentdConf}";
      };

    };
  };

  testScript = ''
    $machine->waitForUnit("docker.service");
    $machine->waitForUnit("fluentd.service");
    $machine->succeed("${runStack}");
    # fluentd has flush_interval set to 60s by default
    $machine->sleep(60);
    $machine->waitUntilSucceeds("journalctl --unit fluentd --no-pager | grep stdout-svc");
    $machine->waitUntilSucceeds("journalctl --unit fluentd --no-pager | grep syslog-svc");
  '';
in
  makeTest { name = "fluentd"; nodes = { inherit machine; }; testScript = testScript; }
    // { driverDockerCompose = runStack; }
