{ pkgs
, contrailPkgs
, contrailPath
}:

with import (pkgs.path + /nixos/lib/testing.nix) { system = builtins.currentSystem; };

let

  dump = pkgs.fetchzip {
    name = "cassandra-dump";
    url = http://nexus.int0.aub.cloudwatt.net/nexus/content/sites/nix/cassandra-dump-prd1-2018-06-25.tgz;
    sha256 = "0dp3jnbl8mlficrmavna699zsmf2369z5568lshhcxg3n60nrdm9";
    stripRoot = false;
  };

  machine = {pkgs, config, ...}: {
    imports = [
      (contrailPath + "/modules/contrail-database-loader.nix")
      (contrailPath + "/modules/gremlin-server.nix")
    ];
    config = {
      _module.args = { inherit contrailPkgs; };

      services.openssh.enable = true;
      services.openssh.permitRootLogin = "yes";
      users.extraUsers.root.password = "";

      contrail.databaseLoader = {
        enable = true;
        cassandraDumpPath = dump;
      };

      gremlin.server.enable = true;

    };
  };

  testScript = ''
    $machine->sleep(500);
    $machine->waitForOpenPort(8182);
    $machine->succeed("${contrailPkgs.tools.contrailGremlin}/bin/gremlin-send 'g.V().count()'");
  '';

in
  makeTest { name = "gremlin-dump"; nodes = { inherit machine; }; inherit testScript; }
