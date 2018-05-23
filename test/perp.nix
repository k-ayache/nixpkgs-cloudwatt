{ pkgs
, pkgs_path ? <nixpkgs>
, lib
}:

with import (pkgs_path + /nixos/lib/testing.nix) { system = builtins.currentSystem; };

let

  tests = [

    # service should run as root
    rec {
      name = "root-svc";
      script = ''
        touch /root/${name}
        tail -f /dev/null
      '';
      service = {
        user = "root";
      };
      succeed = [
        "ls /root/${name}"
      ];
    }

    # environmentFile is available to the service
    rec {
      name = "root-runenv";
      script = ''
        touch $VAR
        tail -f /dev/null
      '';
      service = {
        user = "root";
        environmentFile = pkgs.writeTextFile {
          name = "env";
          text = ''
            VAR=/root/${name}
          '';
        };
      };
      succeed = [
        "ls /root/${name}"
      ];
    }

    # environment variable exported in preStartScript
    # should be available to the service
    rec {
      name = "root-prestart-env";
      script = ''
        echo $VAR > /root/${name}
        tail -f /dev/null
      '';
      service = {
        user = "root";
        preStartScript = ''
          export VAR=root
          touch /root/${name}
        '';
      };
      succeed = [
        "ls /root/${name}"
        "cat /root/${name} | grep root"
      ];
    }

    # service should be run as nobody user
    rec {
      name = "user-svc";
      script = ''
        touch /tmp/${name};
        tail -f /dev/null
      '';
      service = {
        user = "nobody";
      };
      succeed = [
        "find /tmp -name ${name} -user nobody | grep '.*'"
      ];
    }

    # environmentFile is available to the user service
    rec {
      name = "user-runenv";
      script = ''
        touch $VAR
        tail -f /dev/null
      '';
      service = {
        environmentFile = pkgs.writeTextFile {
          name = "env";
          text = ''
            VAR=/tmp/${name}
          '';
        };
      };
      succeed = [
        "find /tmp -name ${name} -user nobody | grep '.*'"
      ];
    }

    # environment variable exported in preStartScript
    # should be available to the user service
    rec {
      name = "user-prestart-env";
      script = ''
        echo $VAR > /tmp/${name}
        tail -f /dev/null
      '';
      service = {
        preStartScript = ''
          export VAR=root
          touch /tmp/${name}
        '';
      };
      succeed = [
        "find /tmp -name ${name} -user nobody | grep '.*'"
        "cat /tmp/${name} | grep root"
      ];
    }

    # environmentFile can be created in preStartScript
    rec {
      name = "user-prestart-runenv";
      script = ''
        echo $VAR > /tmp/${name}
        tail -f /dev/null
      '';
      service = {
        preStartScript = ''
          echo VAR=root > /tmp/env
        '';
        environmentFile = "/tmp/env";
      };
      succeed = [
        "find /tmp -name ${name} -user nobody | grep '.*'"
        "cat /tmp/${name} | grep root"
      ];
    }

    # make sure the service is run in the
    # `chdir` directory
    rec {
      name = "user-chdir";
      script = ''
        touch ${name}
        tail -f /dev/null
      '';
      service = {
        chdir = "/tmp";
      };
      succeed = [
        "ls /tmp/${name}"
      ];
    }

    # when an error occurs in the preStartScript
    # the service should not be run
    rec {
      name = "user-prestart-failure";
      script = ''
        touch /tmp/${name}
        tail -f /dev/null
      '';
      service = {
        preStartScript = ''
          touch /root/${name}
        '';
      };
      fail = [
        "ls /tmp/${name}"
      ];
    }

    # make sure a oneshot service is run exactly one time
    rec {
      name = "oneshot";
      script = ''
        echo "oneshot" >> /tmp/oneshot
      '';
      service = {
        oneShot = true;
      };

      testScript = ''
        $machine->succeed("sleep 6");
        $machine->succeed("docker exec ${name} cat /tmp/oneshot | wc -l  | xargs test 1 -eq");
        # A oneshot service can be reactivated and is then reexecuted exactly onetime
        $machine->succeed("docker exec ${name} perpctl A ${name}");
        $machine->succeed("sleep 4");
        $machine->succeed("docker exec ${name} cat /tmp/oneshot | wc -l  | xargs test 2 -eq");
      '';
    }
  ];

  mkImage = test:
    let
      script = pkgs.writeShellScriptBin "script" test.script;
      service = test.service // {
        name = test.name;
        command = "${script}/bin/script";
      };
    in
      lib.buildImageWithPerps {
        name = test.name;
        fromImage = lib.images.kubernetesBaseImage;
        services = [ service ];
      };

  images = map mkImage tests;

  loadImage = image: ''
    $machine->succeed("docker load -i ${image}");
  '';

  loadImages = builtins.concatStringsSep "\n" (map loadImage images);

  runImage = test: ''
    $machine->succeed("docker run --rm -d --name ${test.name} -h ${test.name} ${test.name}");
  '';

  runImages = builtins.concatStringsSep "\n" (map runImage tests);

  runTest = test@{ succeed ? [], fail ? [], testScript ? "", ... }:
    testScript +
    (builtins.concatStringsSep "\n"
      ((map (e: "$machine->succeed(\"docker exec ${test.name} ${e}\");") succeed) ++
       (map (e: "$machine->fail(\"docker exec ${test.name} ${e}\");") fail)));

  runTests = builtins.concatStringsSep "\n" (map runTest tests);

  machine = { config, ... }: {
    config = rec {
      services.openssh.enable = true;
      services.openssh.permitRootLogin = "yes";
      users.extraUsers.root.password = "root";

      virtualisation = { diskSize = 4960; memorySize = 1024; };
      virtualisation.docker.enable = true;
    };
  };

  testScript = ''
    $machine->waitForUnit("docker.service");
    $machine->succeed("docker container prune --force");
    ${loadImages}
    ${runImages}
    ${runTests}
  '';
in
  makeTest { name = "perp"; nodes = { inherit machine; }; testScript = testScript; }
