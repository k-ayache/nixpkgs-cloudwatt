{ config, lib, pkgs, cwPkgs, cwLibs, ... }:

with builtins;
with lib;

let

  cfg = config.keystone.k8s;

  keystoneLib = import ./lib/keystone_k8s.nix { inherit pkgs; };
  keystoneConfig = import ./config/keystone_k8s.nix { inherit pkgs cwPkgs cwLibs config; };

  defaultProjects = {
    openstack = {
      users = {
        admin = {
          password = keystoneConfig.keystoneAdminPassword;
          roles = ["admin"];
        };
      };
    };
  };

  defaultCatalog = with keystoneConfig; {
    identity = {
      name = "keystone";
      admin_url = "http://${keystoneApiAdminHost}.${config.networking.domain}:${toString adminApiPort}/v2.0";
      internal_url = "http://${keystoneApiHost}.${config.networking.domain}:${toString apiPort}/v2.0";
      public_url = "http://${keystoneApiHost}.${config.networking.domain}:${toString apiPort}/v2.0";
    };
  };

in {

  options = {

    keystone.k8s = {

      enable = mkOption {
        type = types.bool;
        default = false;
      };

      projects = mkOption {
        type = types.attrsOf types.attrs;
        default = {};
      };

      roles = mkOption {
        type = types.listOf types.str;
        default = [ "admin" "Member" ];
        description = ''
          List of roles to provision.
        '';
      };

      catalog = mkOption {
        type = types.attrs;
        default = {};
        description = ''
          Services to be declared in keystone catalog.
        '';
      };

    };

  };

  imports = [
    ./infra_k8s.nix
    ./mysql_k8s.nix
  ];

  config = mkIf cfg.enable {

    environment.etc = with keystoneConfig; {
      "kubernetes/keystone/api.deployment.json".text = keystoneDeployment "api" apiPort;
      "kubernetes/keystone/admin-api.deployment.json".text = keystoneDeployment "admin-api" adminApiPort;
      "kubernetes/keystone/api.service.json".text = keystoneService "api";
      "kubernetes/keystone/admin-api.service.json".text = keystoneService "admin-api";
      "openstack/admin-token.openrc".source = keystoneAdminTokenRc;
      "openstack/admin.openrc".source = keystoneAdminRc;
    };

    environment.systemPackages = with pkgs; [
      cwPkgs.openstackClient
    ];

    systemd.services.keystone = {
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      wantedBy = [ "kubernetes.target" ];
      after = [ "kube-bootstrap.service" "mysql-bootstrap.service" ];
      path = [ pkgs.kubectl pkgs.docker cwPkgs.waitFor cwPkgs.openstackClient ];
      script = ''
        kubectl apply -f /etc/kubernetes/keystone/
      '';
      postStart = with keystoneConfig; with keystoneLib; ''
        wait-for ${keystoneApiAdminHost}:${toString adminApiPort} -q -t 300
        source ${keystoneAdminTokenRc}
        ${createCatalog (defaultCatalog // cfg.catalog) region}
        ${createRoles cfg.roles}
        ${createProjects (defaultProjects // cfg.projects)}
      '';
    };

    infra.k8s = {

      enable = true;

      seedDockerImages = [ cwPkgs.dockerImages.pulled.keystoneAllImage ];

      consulData = with keystoneConfig; {
        "config/openstack/catalog/${region}/data" = defaultCatalog // cfg.catalog;
      };

      vaultData = {
        "secret/keystone" = {
          admin_password = "development";
          admin_token = keystoneConfig.keystoneAdminToken;
          db_password = keystoneConfig.keystoneDBPassword;
        };
        "secret/fernet-keys" = {
          creation_time = 1519801272;
          period = 61536000;
          keys = [
            "1tJnlk8E8KPcUoI0zdvm0Ya9g1EnEPovKiIDTOZtH6g="
            "GIqEyxCbcrNVbaFD6iHYmVR7ktZZyH7brYFrA8yv5H4="
            "QT811eEHXpLvprOiCgnI5DLddx_rA5xD7TDgx0cM_3A="
          ];
          ttl = "3600s";
        };
        "secret/openstack/users/deployment" = {
          project = "deployment";
          password = "development";
          email = "mco@cloudwatt.net";
          roles = [ "Member" "admin" ];
        };
      };

      vaultRoles = {
        periodic-fernet-reader = {
          allowed_policies = "fernet-keys-read";
          explicit_max_ttl = 0;
          name = "periodic-fernet";
          orphan = true;
          path_suffix = "";
          period = 3600;
          renewable = true;
        };
        periodic-fernet-writer = {
          allowed_policies = "fernet-keys-write";
          explicit_max_ttl = 0;
          name = "periodic-fernet";
          orphan = true;
          path_suffix = "";
          period = 3600;
          renewable = true;
        };
      };

      vaultPolicies = {
        applications_token_creator = {
          "auth/token/create/periodic-fernet-reader" = {
            capabilities = [ "create" "read" "update" "delete" "list" ];
          };
          "auth/token/create/periodic-fernet-writer" = {
            capabilities = [ "create" "read" "update" "delete" "list"];
          };
          "auth/token/roles/periodic-fernet-reader" = {
            capabilities = [ "read" ];
          };
          "auth/token/roles/periodic-fernet-writer" = {
            capabilities = [ "read" ];
          };
        };
        keystone = {
          "secret/keystone" = {
            policy = "read";
          };
        };
        fernet-keys-read = {
          "secret/fernet-keys" = {
            capabilities = [ "create" "read" "update" "delete" "list" ];
          };
          "secret/locksmith/consul" = {
            policy = "read";
          };
        };
        fernet-keys-write = {
          "secret/fernet-keys" = {
            policy = "write";
          };
        };
      };

    };

    mysql.k8s = {

      enable = true;

      databases = {
        keystone = {
          user = "keystone";
          password = keystoneConfig.keystoneDBPassword;
        };
      };

      aliases = [ "keystone-db" ];

    };

  };

}
