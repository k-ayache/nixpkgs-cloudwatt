# To debug the test, you can run the test script like:
# ./result/bin/nixos-test-driver 2>&1 | tee log
# Then you can check the log for issues:
# grep -e 'must succeed\|running command\|exit status' log

{ pkgs
, cwPkgs
, contrailPath
, contrailPkgs
, lib
, stdenv
}:

with import (pkgs.path + /nixos/lib/testing.nix) { system = builtins.currentSystem; };

let

  infrastructure =
    let
      rev = "a3cc21135fad25e395ff1c84d47bebc95c6cd930";
      sha256 = "1kynpqhhg8y0kjklgf4w2jg4860ijw9mkk2h63faxbvw0ikhi08l";
    in stdenv.mkDerivation {
      name = "infrastructure";
      src = pkgs.fetchzip {
        url = "https://git.corp.cloudwatt.com/applications/deployment/repository/${rev}/archive.tar.gz";
        inherit sha256;
      };
      phases = [ "unpackPhase" "patchPhase" "installPhase" "fixupPhase" ];
      patchPhase = ''
        ${pkgs.gnused}/bin/sed -i 's!development/dnsmasq!eon/dnsmasq!' docker-compose/infrastructure.yml
        ${pkgs.gnused}/bin/sed -i 's/docker-compose -f infrastructure.yml up$/& -d/' docker-compose/Makefile
        ${pkgs.gnused}/bin/sed -i 's/docker-compose -f openstack.yml up$/& -d/' docker-compose/Makefile
        # speedup mysql/rabbitmq provisioning
        ${pkgs.gnused}/bin/sed -i 's/"RABBITMQ_USERS=.*/"RABBITMQ_USERS=opencontrail"/' docker-compose/openstack.yml
        ${pkgs.gnused}/bin/sed -i 's/"RABBITMQ_VHOSTS=.*/"RABBITMQ_VHOSTS=opencontrail"/' docker-compose/openstack.yml
        ${pkgs.gnused}/bin/sed -i 's/"MYSQL_DATABASES=.*/"MYSQL_DATABASES=keystone"/' docker-compose/openstack.yml
      '';
      installPhase = ''
        mkdir -p $out
        cp -r * $out/
      '';
    };

  keystone =
    let
      rev = "c1d3389b15e5f511bb2bb5d7751ece0341b2f0fd";
      sha256 = "08l7cag28j0711879hzgszmi8mi8bn1ph6b6zm1pfkfw3vn867c0";
    in stdenv.mkDerivation {
      name = "keystone";
      src = pkgs.fetchzip {
        url = "https://git.corp.cloudwatt.com/docker/keystone-all/repository/${rev}/archive.tar.gz";
        inherit sha256;
      };
      phases = [ "unpackPhase" "patchPhase" "installPhase" "fixupPhase" ];
      patchPhase = ''
        ${pkgs.gnused}/bin/sed -i 's/@docker-compose up$/& -d/' Makefile
        ${pkgs.gnused}/bin/sed -i 's/all:9.0.0-1/all:latest/' docker-compose.yml
      '';
      installPhase = ''
        mkdir -p $out
        cp -r * $out/
      '';
    };

  images = with cwPkgs.dockerImages; [
    # infrastructure
    pulled.consulAgentImage
    pulled.developmentDnsmaskImage
    pulled.developmentFluentdImage
    pulled.developmentPolipoImage
    pulled.developmentPolymurImage
    pulled.developmentRegistratorImage
    pulled.developmentVaultImage
    # openstack
    pulled.developmentMysqlImage
    pulled.developmentRabbitmqImage
    # keystone
    pulled.openstackToolsImage
    pulled.keystoneAllImage
    # contrail
    pulled.zookeeperImage
    pulled.cassandraImage
    contrailApi
    contrailDiscovery
    contrailControl
    contrailSchemaTransformer
    contrailSvcMonitor
    contrailAnalytics
  ];

  openstackRegion = "dev0";
  keystoneProtocol = "http";
  keystoneHost = "identity-admin.dev0.loc.cloudwatt.net";
  keystoneAdminPort = "35357";
  keystoneAdminUrl = "${keystoneProtocol}://${keystoneHost}:${keystoneAdminPort}/v2.0";
  keystoneProject = "openstack";
  keystoneUser = "admin";
  keystonePassword = "development";

  publicNetName = "public";
  publicNetPrefix = "10.0.0.0";
  publicNetPrefixLen = 24;

  keystoneAdminTokenRc = pkgs.writeTextFile {
    name = "admin-token.openrc";
    text = ''
      export OS_AUTH_TYPE="v2token"
      export OS_AUTH_URL="${keystoneAdminUrl}"
      export OS_TOKEN="${keystonePassword}"
      export CONTRAIL_API_HOST=controller
    '';
  };

  keystoneAdminRc = pkgs.writeTextFile {
    name = "admin.openrc";
    text = ''
      export OS_AUTH_TYPE="v2password"
      export OS_AUTH_URL="${keystoneAdminUrl}"
      export OS_REGION_NAME="${openstackRegion}"
      export OS_PROJECT_NAME="${keystoneProject}"
      # mandatory for contrail-api-cli
      export OS_TENANT_NAME="${keystoneProject}"
      export OS_USERNAME="${keystoneUser}"
      export OS_PASSWORD="${keystonePassword}"
      export OS_INTERFACE="admin"
      export CONTRAIL_API_HOST=controller
    '';
  };

  vncApiLib = pkgs.writeTextFile {
    name = "vnc_api_lib.ini";
    text = ''
      [auth]
      AUTHN_TYPE = keystone
      AUTHN_PROTOCOL = ${keystoneProtocol}
      AUTHN_SERVER = ${keystoneHost}
      AUTHN_PORT = ${keystoneAdminPort}
      AUTHN_URL = /v2.0/tokens
      AUTHN_TOKEN_URL = ${keystoneAdminUrl}/tokens
    '';
  };

  loadImage = image: with lib.image; ''
    $controller->succeed("docker load -i ${image}");
    $controller->succeed("docker tag ${imageName image}:${imageTag image} ${imageName image}:latest");
  '';
  loadImages = builtins.concatStringsSep "\n" (map loadImage images);

  # Don't use the disco since it will report docker IPs but vrouter VM
  # has no access to them
  vrouterConfig = ip: pkgs.writeTextFile {
    name = "contrail-vrouter-agent.conf";
    text = ''
      [DEFAULT]
      disable_flow_collection = 1
      log_level = SYS_DEBUG
      collectors = 192.168.1.1:8086

      [CONTROL-NODE]
      server = 192.168.1.1

      [VIRTUAL-HOST-INTERFACE]
      name = vhost0
      ip = 192.168.2.${ip}/24
      gateway = 192.168.2.1
      physical_interface = eth2

      [FLOWS]
      max_vm_flows = 20

      [METADATA]
      metadata_proxy_secret = t96a4skwwl63ddk6

      [TASK]
      tbb_keepawake_timeout = 25

      [SERVICE-INSTANCE]
      netns_command=${contrailPkgs.vrouterNetns}/bin/opencontrail-vrouter-netns
    '';
  };

  vrouter = ip: { config, ... }: {
    imports = [ (contrailPath + "/modules/compute-node.nix") ];

    config = {
      _module.args = { inherit contrailPkgs; isContrailMaster=false; isContrail32=true; };

      services.openssh.enable = true;
      services.openssh.permitRootLogin = "yes";
      services.openssh.extraConfig = "PermitEmptyPasswords yes";
      users.extraUsers.root.password = "";

      networking.firewall.enable = false;
      networking.hosts = {
        "192.168.1.1" = [ "identity-admin.dev0.loc.cloudwatt.net" "identity.dev0.loc.cloudwatt.net" ];
      };

      environment.etc = {
        "keystone/admin-token.openrc".source = keystoneAdminTokenRc;
        "keystone/admin.openrc".source = keystoneAdminRc;
        "contrail/vnc_api_lib.ini".source = vncApiLib;
      };

      virtualisation.memorySize = 1024;
      virtualisation.vlans = [ 1 2 ];
      virtualisation.graphics = false;

      contrail.vrouterAgent = {
        enable = true;
        provisionning = false;
        configurationFilepath = "${vrouterConfig ip}";
        contrailInterfaceName = "eth2";
      };

      # TODO: add in compute module
      systemd.services.addVGW = {
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        wantedBy = [ "multi-user.target" ];
        after = [ "contrailVrouterAgent.service" ];
        script = ''
          ${cwPkgs.waitFor}/bin/wait-for localhost:9091
          ${contrailPkgs.configUtils}/bin/provision_vgw_interface.py --oper create \
              --interface vgw --subnets ${publicNetPrefix}/${toString publicNetPrefixLen} --routes 0.0.0.0/0 \
              --vrf "default-domain:service:${publicNetName}:${publicNetName}"
        '';
      };

    };

  };

  contrailProvision = pkgs.writeTextFile {
    name = "provision.json";
    text = ''
      {
          "name": "test",
          "namespace": "contrail_api_cli.provision",
          "defaults": {
              "vn": {
                  "project-fqname": "default-domain:service"
              },
              "lr": {
                  "project-fqname": "default-domain:service"
              }
          },
          "provision": {
              "encaps": {
                "modes": [
                  "MPLSoGRE",
                  "MPLSoUDP",
                  "VXLAN"
                ]
              },
              "vrouter": [
                {
                  "vrouter-ip": "192.168.2.2",
                  "vrouter-name": "vrouter1"
                },
                {
                  "vrouter-ip": "192.168.2.3",
                  "vrouter-name": "vrouter2"
                }
              ],
              "vn": [
                  {
                    "virtual-network-name": "${publicNetName}",
                    "subnets": [
                      "${publicNetPrefix}/${toString publicNetPrefixLen}"
                    ],
                    "external": true
                  },
                  {
                    "virtual-network-name": "vn1",
                    "subnets": [
                      "20.1.1.0/24"
                    ]
                  },
                  {
                    "virtual-network-name": "vn2",
                    "subnets": [
                      "20.2.2.0/24"
                    ]
                  }
              ],
              "lr": {
                  "logical-router-name": "router",
                  "vn-fqnames": [
                    "default-domain:service:vn1",
                    "default-domain:service:vn2"
                  ],
                  "external-vn-fqname": "default-domain:service:${publicNetName}"
              }
          }
      }
    '';
  };

  controller = { config, ... }: {
    config = rec {
      services.openssh.enable = true;
      services.openssh.permitRootLogin = "yes";
      services.openssh.extraConfig = "PermitEmptyPasswords yes";
      users.extraUsers.root.password = "";

      networking.firewall.enable = false;
      networking.hosts = {
        "127.0.1.1" = [ "identity-admin.dev0.loc.cloudwatt.net" "identity.dev0.loc.cloudwatt.net" ];
      };
      # we ping the controller from contrail with an IP from the public network
      # so the controller needs to know to send back packets. Destination can
      # be either vrouter.
      networking.interfaces.eth1.ipv4.routes = [
        { address = publicNetPrefix; prefixLength = publicNetPrefixLen; via = "192.168.1.2"; }
      ];

      virtualisation = {
        diskSize = 10000;
        memorySize = 4096;
        cores = 2;
        graphics = false;
      };
      virtualisation.docker.enable = true;

      # # forward some ports on the host for debugging
      # virtualisation.qemu.networkingOptions = [
      #   "-net nic,netdev=user.0,model=virtio"
      #   "-netdev user,id=user.0,hostfwd=tcp::2222-:22,hostfwd=tcp::8083-:8083"
      # ];

      environment.systemPackages = [
        # deps for test script
        pkgs.docker_compose
        pkgs.gnumake
        pkgs.curl
        pkgs.vault
        pkgs.jq
        cwPkgs.openstackClient
        contrailPkgs.tools.contrailApiCliWithExtra
      ];

      environment.etc = {
        "docker/daemon.json".text = ''
          {
            "dns-opts": ["ndots:2"]
          }
        '';
        "keystone/admin-token.openrc".source = keystoneAdminTokenRc;
        "keystone/admin.openrc".source = keystoneAdminRc;
        "contrail/vnc_api_lib.ini".source = vncApiLib;
        "contrail/provision.json".source = contrailProvision;
      };

    };
  };

  vaultEnv = "infrastructure/docker-compose/.docker-compose/vault.env";

  # we don't care about setting a correct tenant_id or user_id
  # because is_admin is set to true
  vncOpenstackRequest = pkgs.writeTextFile {
    name = "request.json";
    text = builtins.toJSON {
      context = {
        type = "network";
        operation = "READALL";
        tenant_id = "6d5e09f8e1194f928afece567b6e56f5";
        user_id = "6d5e09f8e1194f928afece567b6e56f5";
        request_id = "req-f79fa546-ec4c-4bcc-9f4d-b535974312b8";
        is_admin = true;
      };
      data = {
        fields = [];
        filters = {};
      };
    };
  };

  checkVncOpenstack = pkgs.writeShellScriptBin "check-vnc_openstack" ''
    source ${keystoneAdminRc}
    export TOKEN=$(openstack token issue -f value -c id)
    curl -i -X POST -H "X-Auth-Token: $TOKEN" -H "Content-type: application/json" \
      --data @${vncOpenstackRequest} http://localhost:8082/neutron/network | grep -q '200 OK'
  '';

  # working directory is /tmp
  testScript = ''
    my $ret;
    my $out;
    sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

    startAll;

    $controller->waitForUnit("docker.service");

    ${loadImages}

    $controller->succeed("mkdir -p infrastructure keystone contrail");
    $controller->succeed("cp -r ${infrastructure}/* infrastructure/");
    $controller->succeed("cp -r ${keystone}/* keystone/");
    $controller->succeed("cp -r ${../docker-compose}/* contrail/");

    # infra
    $controller->succeed("[ ! -f ${vaultEnv} ] && cd infrastructure/docker-compose && make vault-init || exit 0");
    $controller->succeed("source ${vaultEnv} && cd infrastructure/docker-compose && make infrastructure-up");
    # wait for vault unseal
    $controller->waitUntilSucceeds("vault status -tls-skip-verify");

    # openstack DBs
    $controller->succeed("source ${vaultEnv} && cd infrastructure/docker-compose && make openstack-up");
    # wait for mysql provisioning
    $controller->waitUntilSucceeds("docker exec dockercompose_openstack-db_1 mysql mysql -e 'select user from user' | grep keystone");
    # wait for rabbitmq provisioning
    $controller->waitUntilSucceeds("docker exec dockercompose_openstack-queue_1 rabbitmqctl list_permissions -p opencontrail | grep -e ^opencontrail");

    # keystone
    $controller->succeed("source ${vaultEnv} && cd keystone && make dev-up");
    $controller->sleep(20);
    ($ret, $out) = $controller->execute("source ${keystoneAdminTokenRc} && openstack user list --project openstack | grep -q admin");
    if ($ret != 0) {
      $controller->succeed("source ${vaultEnv} && cd keystone && make dev-service-user");
      $controller->succeed("source ${vaultEnv} && cd infrastructure/docker-compose && make openstack-catalog");
    }

    # contrail
    $controller->succeed("source ${vaultEnv} && cd contrail && make dev-consul-data");
    $controller->waitUntilSucceeds("source ${vaultEnv} && cd contrail && make dev-vault-data");
    ($ret, $out) = $controller->execute("source ${keystoneAdminTokenRc} && openstack user list --project service | grep -q opencontrail");
    if ($ret != 0) {
      $controller->succeed("source ${vaultEnv} && cd contrail && make contrail-service-user");
    } else {
      $controller->succeed("source ${vaultEnv} && cd contrail && make contrail-clean");
    }

    # start services, we don't start vrouter/vrouter-master/svc-monitor
	$controller->succeed("source ${vaultEnv} && cd contrail && docker-compose -f contrail.yml up -d cassandra zookeeper api discovery control schema analytics svc-monitor");

    # check services state
    my @services = qw(ApiServer IfmapServer Collector OpServer);
    foreach my $service (@services)
    {
      $controller->waitUntilSucceeds(sprintf("curl -s localhost:5998/services.json | jq -e '.services[] | select(.service_type == \"%s\" and .oper_state == \"up\")'", $service));
    }

    # check api
    $controller->waitUntilSucceeds("curl -s http://localhost:8082");

    # provision controller
    my $controllerName = $controller->succeed("cd contrail && docker-compose -f contrail.yml ps -q control 2>/dev/null | cut -c -12");
    my $controllerIP = $controller->succeed("curl -s localhost:8500/v1/catalog/service/opencontrail-control | jq -r .[].ServiceAddress");
    $controller->succeed(sprintf("source ${keystoneAdminRc} && contrail-api-cli --ns contrail_api_cli.provision add-bgp-router --router-ip %s %s", trim($controllerIP), trim($controllerName)));

    # check controller state
    $controller->waitUntilSucceeds("curl -s localhost:5998/services.json | jq -e '.services[] | select(.service_type == \"xmpp-server\" and .oper_state == \"up\")'");

    # create service project
    $controller->succeed("source ${keystoneAdminRc} && contrail-api-cli exec contrail/create_project.py");

    # provision vns etc...
    $controller->succeed("source ${keystoneAdminRc} && contrail-api-cli provision -f ${contrailProvision}");

    # check vnc_openstack
    $controller->succeed("${checkVncOpenstack}/bin/check-vnc_openstack");

    # check all vrouters are present and functionnal
    $controller->waitUntilSucceeds("curl -s localhost:8081/analytics/uves/vrouters | jq '. | length' | grep -q 2");
    $controller->waitUntilSucceeds("curl -s localhost:8081/analytics/uves/vrouter/*?cfilt=NodeStatus:process_status | jq -e '.[][].value.NodeStatus.process_status[] | select(.state == \"Functional\")'");

    # test ping
    $vrouter1->succeed("netns-daemon-start -U opencontrail -P development -s controller -n default-domain:service:vn1 vm1");
    $vrouter2->succeed("netns-daemon-start -U opencontrail -P development -s controller -n default-domain:service:vn1 vm2");
    $vrouter2->succeed("netns-daemon-start -U opencontrail -P development -s controller -n default-domain:service:vn2 vm3");
    $vrouter1->succeed("ip netns exec ns-vm1 ip a | grep -q 20.1.1.252");
    # ping in same network
    $vrouter1->succeed("ip netns exec ns-vm1 ping -c1 20.1.1.251");
    # ping through router
    $vrouter1->succeed("ip netns exec ns-vm1 ping -c1 20.2.2.252");
    # check snat is properly scheduled on each vrouter
    $vrouter1->waitUntilSucceeds("ip netns | grep -q vrouter");
    $vrouter2->waitUntilSucceeds("ip netns | grep -q vrouter");
    # ping controller via SNAT
    # first ping may fails, but next one should succeed
    $vrouter1->waitUntilSucceeds("ip netns exec ns-vm1 ping -c1 192.168.1.1");
  '';

in
  makeTest {
    name = "contrail";
    nodes = {
      inherit controller;
      # IPs for vrouters will be 192.168.1.{2,3}
      vrouter1 = vrouter "2";
      vrouter2 = vrouter "3";
    };
    testScript = testScript;
  }
