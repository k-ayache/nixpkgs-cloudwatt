{ pkgs
, cwPkgs
, lib
, stdenv
}:

with import (pkgs.path + /nixos/lib/testing.nix) { system = builtins.currentSystem; };

let

  master = { config, ... }: {

    imports = [
      ../modules/keystone_k8s.nix
    ];

    config = {
      _module.args = { inherit cwPkgs; cwLibs = lib; };

      services.openssh.enable = true;
      services.openssh.permitRootLogin = "yes";
      services.openssh.extraConfig = "PermitEmptyPasswords yes";
      users.extraUsers.root.password = "";

      keystone.k8s = {
        enable = true;
        roles = [ "admin" "Member" "test" ];
        projects = {
          test = {
            users = {
              test = {
                password = "test";
                roles = [ "admin" "test" ];
              };
            };
          };
        };
        catalog = {
          foo = {
            name = "foo";
            admin_url = "http://foo.service.${config.networking.domain}:4444/v2.0";
            internal_url = "http://foo.service.${config.networking.domain}:4444/v2.0";
            public_url = "http://foo.service.${config.networking.domain}:4444/v2.0";
          };
        };
      };

      virtualisation = {
        diskSize = 10000;
        memorySize = 2048;
      };

      # # forward some ports on the host for debugging
      # virtualisation.qemu.networkingOptions = [
      #   "-net nic,netdev=user.0,model=virtio"
      #   "-netdev user,id=user.0,hostfwd=tcp::2222-:22"
      # ];

    };

  };

  testScript = ''
    $master->waitForUnit("keystone.service");
    # check keystone is running
    $master->waitUntilSucceeds("curl -s consul:8500/v1/catalog/services | grep -q keystone-admin-api");
    $master->waitUntilSucceeds("curl -s consul:8500/v1/catalog/services | grep -q keystone-api");
    # check keystone is provisioned
    $master->waitUntilSucceeds("source /etc/openstack/admin-token.openrc && openstack user list | grep -q admin");
    $master->waitUntilSucceeds("source /etc/openstack/admin.openrc && openstack user list | grep -q test");
    $master->waitUntilSucceeds("source /etc/openstack/admin.openrc && openstack role list | grep -q test");
    $master->waitUntilSucceeds("source /etc/openstack/admin.openrc && openstack catalog list | grep -q foo");
    $master->waitUntilSucceeds("source /etc/openstack/admin.openrc && openstack catalog list | grep -q identity");
  '';

in
  makeTest {
    name = "keystone";
    nodes = {
      inherit master;
    };
    testScript = testScript;
  }
