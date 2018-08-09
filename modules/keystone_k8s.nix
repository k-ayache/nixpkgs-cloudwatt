{ config, lib, pkgs, cwPkgs, cwLibs, ... }:

with builtins;
with lib;

let

  cfg = config.keystone.k8s;

  apiPort = 5000;
  adminApiPort = 35357;

  keystoneApiAdminHost = "keystone-admin-api-pods.service";
  keystoneApiHost = "keystone-api-pods.service";

  keystoneAdminPassword = "development";
  keystoneAdminToken = "development";
  keystoneDBPassword = "development";

  imageName = "r.cwpriv.net/keystone/all";
  imageTag = "9.0.0-61516ea9ed2202a1";
  sha256 = "1z944khvnp0z4mchnkxb5pgm9c29cll5v544jin596pwgrqbcw99";

  region = head (splitString "." config.infra.k8s.domain);

  keystoneAdminTokenRc = pkgs.writeTextFile {
    name = "admin-token.openrc";
    text = ''
      export OS_URL="http://${keystoneApiAdminHost}.${config.infra.k8s.domain}:${toString adminApiPort}/v2.0"
      export OS_TOKEN="${keystoneAdminToken}"
    '';
  };

  keystoneAdminRc = pkgs.writeTextFile {
    name = "admin.openrc";
    text = ''
      export OS_AUTH_TYPE="v2password"
      export OS_AUTH_URL="http://${keystoneApiAdminHost}.${config.infra.k8s.domain}:${toString adminApiPort}/v2.0"
      export OS_REGION_NAME="${region}"
      export OS_PROJECT_NAME="openstack"
      export OS_TENANT_NAME="openstack"
      export OS_USERNAME="admin"
      export OS_PASSWORD="${keystoneAdminPassword}"
      export OS_INTERFACE="admin"
    '';
  };

  defaultProjects = {
    openstack = {
      users = {
        admin = {
          password = keystoneAdminPassword;
          roles = ["admin"];
        };
      };
    };
  };

  defaultCatalog = {
    identity = {
      name = "keystone";
      admin_url = "http://${keystoneApiAdminHost}.${config.infra.k8s.domain}:${toString adminApiPort}/v2.0";
      internal_url = "http://${keystoneApiHost}.${config.infra.k8s.domain}:${toString apiPort}/v2.0";
      public_url = "http://${keystoneApiHost}.${config.infra.k8s.domain}:${toString apiPort}/v2.0";
    };
  };

  createProjectUserRole = project: user: roles:
    concatStringsSep "\n" (map (role: ''
      openstack role add --project ${project} --user ${user} ${role}
    '') roles);

  createProjectUsers = project: users:
    concatStringsSep "\n" (mapAttrsToList (user: { password, roles ? [] }: ''
      openstack user create --password '${password}' ${user}
    '' + optionalString (roles != []) (createProjectUserRole project user roles)) users);

  createProject = project: { users ? {} }: ''
    openstack project create ${project}
  '' + optionalString (users != {}) (createProjectUsers project users);

  createProjects = projects:
    concatStringsSep "\n" (mapAttrsToList createProject projects);

  createCatalog = catalog:
    concatStringsSep "\n" (mapAttrsToList (type: { name, admin_url, internal_url, public_url }: ''
      openstack service create --description "${type} service" --name ${name} ${type}
      openstack endpoint create --region ${region} --adminurl "${admin_url}" --internalurl "${internal_url}" \
        --publicurl "${public_url}" ${type}
    '') catalog);

  createRoles = roles:
    concatStringsSep "\n" (map (role: ''
      openstack role create ${role}
    '') roles);

  kubeConfigMap = cwLibs.writeYamlFile {
    name = "configmap.yml";
    text = ''
      ---
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: openstack
        namespace: default
      data:
        region: ${region}
    '';
  };

  keystoneAllImage = pkgs.dockerTools.pullImage {
    inherit imageName imageTag sha256;
  };

  keystoneApiDeployment = service: port: cwLibs.writeYamlFile {
    name = "deployment.yml";
    text = ''
      ---
      apiVersion: extensions/v1beta1
      kind: Deployment
      metadata:
        name: keystone-${service}
      spec:
        replicas: 1
        template:
          metadata:
            labels:
              application: keystone
              service: ${service}
          spec:
            dnsPolicy: Default
            containers:
              - name: keystone-${service}
                image: ${imageName}:${imageTag}
                env:
                  - name: openstack_region
                    valueFrom:
                      configMapKeyRef:
                        name: openstack
                        key: region
                  - name: service
                    value: ${service}
                ports:
                  - containerPort: ${toString port}
                lifecycle:
                  preStop:
                    exec:
                      command: ["/usr/sbin/stop-container"]
                livenessProbe:
                  httpGet:
                    path: /
                    port: 1988
                  initialDelaySeconds: 10
                  periodSeconds: 30
                  timeoutSeconds: 15
                readinessProbe:
                  httpGet:
                    path: /ready
                    port: 1988
                  initialDelaySeconds: 10
                  periodSeconds: 30
                  timeoutSeconds: 15
                volumeMounts:
                  - name: config
                    mountPath: /run/consul-template-wrapper
                  - name: vault-token
                    mountPath: /run/vault-token
                  - name: vault-token-keystone-keys
                    mountPath: /run/vault-token-keystone-keys
            volumes:
              - name: config
                emptyDir:
              - name: vault-token
                flexVolume:
                  driver: cloudwatt/vaulttmpfs
                  fsType: tmpfs
                  options:
                    vault/policies: keystone
              - name: vault-token-keystone-keys
                flexVolume:
                  driver: cloudwatt/vaulttmpfs
                  fsType: tmpfs
                  options:
                    vault/policies: fernet-keys-read
                    vault/role: "periodic-fernet-reader"
                    vault/filePermissions: "640"
                    vault/unwrap: "true"
            terminationGracePeriodSeconds: 1200
    '';
  };

  keystoneApiService = service: port: cwLibs.writeYamlFile {
    name = "service.yml";
    text = ''
      ---
      apiVersion: v1
      kind: Service
      metadata:
        name: keystone-${service}-pods
      spec:
        clusterIP: None
        selector:
          application: keystone
          service: ${service}
        ports:
          - port: ${toString port}
    '';
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

    environment.etc = {
      "kubernetes/openstack/configmap.yml".source = kubeConfigMap;
      "kubernetes/keystone/api.deployment.yml".source = keystoneApiDeployment "api" apiPort;
      "kubernetes/keystone/admin-api.deployment.yml".source = keystoneApiDeployment "admin-api" adminApiPort;
      "kubernetes/keystone/api.service.yml".source = keystoneApiService "api" apiPort;
      "kubernetes/keystone/admin-api.service.yml".source = keystoneApiService "admin-api" adminApiPort;
      "openstack/admin-token.openrc".source = keystoneAdminTokenRc;
      "openstack/admin.openrc".source = keystoneAdminRc;
    };

    systemd.services.keystone = {
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      wantedBy = [ "kubernetes.target" ];
      after = [ "kube-bootstrap.service" "mysql-bootstrap.service" ];
      path = [ pkgs.kubectl pkgs.docker cwPkgs.waitFor cwPkgs.openstackClient ];
      script = ''
        kubectl apply -f /etc/kubernetes/openstack/
        kubectl apply -f /etc/kubernetes/keystone/
      '';
      postStart = ''
        wait-for ${keystoneApiAdminHost}.${config.infra.k8s.domain}:${toString adminApiPort} -q -t 300
        source ${keystoneAdminTokenRc}
        ${createCatalog (defaultCatalog // cfg.catalog)}
        ${createRoles cfg.roles}
        ${createProjects (defaultProjects // cfg.projects)}
      '';
    };

    infra.k8s = {

      enable = true;

      seedDockerImages = [
        keystoneAllImage
      ];

      consulData = {
        "config/openstack/catalog/${region}/data" = defaultCatalog // cfg.catalog;
      };

      vaultData = {
        "secret/keystone" = {
          admin_password = "development";
          admin_token = keystoneAdminToken;
          db_password = keystoneDBPassword;
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
          password = keystoneDBPassword;
        };
      };

      aliases = [ "keystone-db" ];

    };

  };

}
