{ pkgs, cwPkgs, cwLibs, config }:

with builtins;
with pkgs.lib;

rec {

  region = head (splitString "." config.networking.domain);

  apiPort = 5000;
  adminApiPort = 35357;

  keystoneApiAdminHost = "keystone-admin-api.service";
  keystoneApiHost = "keystone-api.service";

  keystoneAdminPassword = "development";
  keystoneAdminToken = "development";
  keystoneDBPassword = "development";

  keystoneAdminTokenRc = pkgs.writeTextFile {
    name = "admin-token.openrc";
    text = ''
      export OS_URL="http://${keystoneApiAdminHost}.${config.networking.domain}:${toString adminApiPort}/v2.0"
      export OS_TOKEN="${keystoneAdminToken}"
    '';
  };

  keystoneAdminRc = pkgs.writeTextFile {
    name = "admin.openrc";
    text = ''
      export OS_AUTH_TYPE="v2password"
      export OS_AUTH_URL="http://${keystoneApiAdminHost}.${config.networking.domain}:${toString adminApiPort}/v2.0"
      export OS_REGION_NAME="${region}"
      export OS_PROJECT_NAME="openstack"
      export OS_TENANT_NAME="openstack"
      export OS_USERNAME="admin"
      export OS_PASSWORD="${keystoneAdminPassword}"
      export OS_INTERFACE="admin"
    '';
  };

  keystoneDeployment = service: port: cwLibs.mkJSONDeployment {
    inherit service port;
    application = "keystone";
    vaultPolicy = "keystone";
    containers = with cwPkgs.dockerImages.pulled; with cwLibs.image; [
      {
        image = "${imageName keystoneAllImage}:${imageTag keystoneAllImage}";
        lifecycle = {
          preStop = {
            exec = { command = ["/usr/sbin/stop-container"]; };
          };
        };
        livenessProbe = cwLibs.mkHTTPGetProbe "/" 1988 10 30 15;
        readinessProbe = cwLibs.mkHTTPGetProbe "/ready" 1988 10 30 15;
        volumeMounts = [
          { name = "vault-token-keystone-keys"; mountPath = "/run/vault-token-keystone-keys"; }
        ];
      }
    ];
    volumes = [
      {
        name = "vault-token-keystone-keys";
        flexVolume = {
          driver = "cloudwatt/vaulttmpfs";
          options = {
            "vault/policies" = "fernet-keys-read";
            "vault/role" = "periodic-fernet-reader";
            "vault/filePermissions" = "640";
            "vault/unwrap" = "true";
          };
        };
      }
    ];
  };

  keystoneService = service: cwLibs.mkJSONService {
    inherit service;
    application = "keystone";
  };

}
