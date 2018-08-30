{ pkgs
, lib
}:

with import (pkgs.path + /nixos/lib/testing.nix) { system = builtins.currentSystem; };

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

    # test after with oneshot services
    rec {
      name = "oneshot-after";
      script1 = pkgs.writeShellScriptBin "script1" ''
        touch /tmp/oneshot-after-touch
      '';
      script2 = pkgs.writeShellScriptBin "script2" ''
        [ -f /tmp/oneshot-after-touch ] && touch /tmp/oneshot-after
        while :; do sleep 1; done
      '';
      script3 = pkgs.writeShellScriptBin "script3" ''
        sleep 1
        exit 1
      '';
      script4 = pkgs.writeShellScriptBin "script4" ''
        touch /tmp/oneshot-after-broken
        while :; do sleep 1; done
      '';
      services = [
        {
          name = "service1";
          oneShot = true;
          command = "${script1}/bin/script1";
        }
        {
          name = "service2";
          after = ["service1"];
          command = "${script2}/bin/script2";
        }
        {
          name = "service3";
          oneShot = true;
          command = "${script3}/bin/script3";
        }
        {
          name = "service4";
          after = ["service3"];
          command = "${script4}/bin/script4";
        }
      ];
      succeed = [
        "ls /tmp/oneshot-after"
        "ls /var/run/perp/service1.success"
        "ls /var/run/perp/service3.fail"
      ];
      fail = [
        "ls /tmp/oneshot-after-broken"
      ];
    }

    # test after with normal services
    rec {
      name = "service-after";
      script1 = pkgs.writeShellScriptBin "script1" ''
        sleep 2
        touch /tmp/service1-after
        while :; do sleep 1; done
      '';
      script2 = pkgs.writeShellScriptBin "script2" ''
        [ -f /tmp/service1-after ] && touch /tmp/service2-after
        while :; do sleep 1; done
      '';
      script3 = pkgs.writeShellScriptBin "script3" ''
        sleep 1
        exit 1
      '';
      script4 = pkgs.writeShellScriptBin "script4" ''
        touch /tmp/service-after-broken
        while :; do sleep 1; done
      '';
      services = [
        {
          name = "service1";
          command = "${script1}/bin/script1";
        }
        {
          name = "service2";
          after = ["service1"];
          command = "${script2}/bin/script2";
        }
      ];
      succeed = [
        "ls /tmp/service2-after"
      ];
      fail = [
        "ls /tmp/service-after-broken"
      ];
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
        services = if test ? "service" then [ service ] else test.services;
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
