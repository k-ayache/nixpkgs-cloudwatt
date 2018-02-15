{ pkgs
, pkgs_path ? <nixpkgs>
, hydraImage
, lib
}:

with import (pkgs_path + /nixos/lib/testing.nix) { system = builtins.currentSystem; };

let
  postgres = pkgs.dockerTools.pullImage {
    imageName = "postgres";
    imageTag = "9.3";
    sha256 = "0nk1zij7hk84sniv0ql86j86m8sh0kxcm652jxkd3wakl7w1ywal";
  };

  runStack = lib.runDockerComposeStack {
    version = "2";
    services = {
      postgres = {
        image = builtins.baseNameOf postgres;
        environment = [ "POSTGRES_PASSWORD=MYPWD" ];
      };
      hydra = {
        image = builtins.baseNameOf hydraImage;
        environment = [ "HYDRA_DBI=dbi:Pg:dbname=postgres;host=postgres;user=postgres;"
                        "POSTGRES_PASSWORD=MYPWD"
                        "HYDRA_ADMIN_USERNAME=admin"
                        "HYDRA_ADMIN_PASSWORD=admin"
                      ];
        ports = [ "3000:3000" ];
        links = [ "postgres:postgres" ];
      };
    };
  };

  machine = {pkgs, config, ...}: {
    config = rec {
      services.openssh.enable = true;
      services.openssh.permitRootLogin = "yes";
      users.extraUsers.root.password = "root";

      virtualisation = { diskSize = 4960; memorySize = 1024; };
      virtualisation.docker.enable = true;
    };
  };

  testScript =
  ''
    $machine->waitForUnit("network.target");
    $machine->waitForUnit("sockets.target");

    $machine->succeed("${runStack}");

    $machine->waitUntilSucceeds('[ $(curl -H "Content-Type: application/json" http://localhost:3000/) == "[]" ]');
  '';
in
  makeTest { name = "hydra"; nodes = { inherit machine; }; testScript = testScript; }
   // { driverDockerCompose = runStack; }
