{ pkgs
, contrailPkgs
, contrailPath
}:

with import (pkgs.path + /nixos/lib/testing.nix) { system = builtins.currentSystem; };

let
  apiConf = import (contrailPath + "/test/configuration/R3.2/api.nix") { inherit pkgs; };

  # First generate a dump:
  # $ mkdir -p /tmp/cassandra-dump'
  # $ cqlsh -e "DESC SCHEMA" > /tmp/cassandra-dump/schema.cql'
  # $ for t in obj_uuid_table obj_fq_name_table; do echo "COPY config_db_uuid.$t TO '/tmp/cassandra-dump/config_db_uuid.$t.csv';" | cqlsh; done
  #
  # Then upload the tgz to Nexus:
  # $ curl -v -u deployment:PASSWORD --upload-file dump.tgz http://nexus.int0.aub.cloudwatt.net/nexus/content/sites/nix
  # where PASSWORD can be found in the Nexus databag of int0
  dump = pkgs.fetchzip {
    name = "cassandra-dump";
    url = http://nexus.int0.aub.cloudwatt.net/nexus/content/sites/nix/cassandra-dump-prd1-2018-06-25.tgz;
    sha256 = "0dp3jnbl8mlficrmavna699zsmf2369z5568lshhcxg3n60nrdm9";
    stripRoot = false;
  };

  machine = {pkgs, config, ...}: {
    imports = [
      (contrailPath + "/modules/contrail-database-loader.nix")
      (contrailPath + "/modules/contrail-api.nix")
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

      contrail.api = {
        enable = true;
        configFile = apiConf;
        waitFor = false;
      };

    };
  };

  testScript = ''
    # Cassandra and contrail-api-server take a while to start and can timeout
    $machine->sleep(600);
    $machine->waitForOpenPort(8082);
    $machine->waitForUnit("contrailApi.service");
    $machine->succeed("${pkgs.curl}/bin/curl localhost:8082/virtual-networks");
  '';

in
  makeTest { name = "contrail-load-database"; nodes = { inherit machine; }; inherit testScript; }
