{ config, lib, pkgs, ... }:

with builtins;
with lib;

let

  cfg = config.mysql.k8s;
  port = 3306;

  createDatabaseUser = db: user: password: ''
    echo "CREATE USER IF NOT EXISTS '${user}'@'%' IDENTIFIED BY '${password}';" | mysql -u root -N
    echo "GRANT ALL PRIVILEGES ON ${db}.* TO '${user}'@'%';" | mysql -u root -N
  '';

  createDatabase = db: { user ? "", password ? "" }: ''
    echo "CREATE DATABASE ${db};" | mysql -u root -N
  '' + optionalString (user != "" && password != "") (createDatabaseUser db user password);

  createDatabases = databases:
    concatStringsSep "\n" (mapAttrsToList createDatabase databases);

in {

  options.mysql.k8s = {

    enable = mkOption {
      type = types.bool;
      default = false;
    };

    aliases = mkOption {
      type = types.listOf types.str;
      description = ''
        Name of services to be registered in consul that
        will point to this service.
      '';
    };

    address = mkOption {
      type = types.str;
      default = "169.254.1.51";
    };

    databases = mkOption {
      type = types.attrsOf types.attrs;
      default = {};
    };

  };

  imports = [
    ./infra_k8s.nix
  ];

  config = mkIf cfg.enable {

    infra.k8s = {
      enable = true;
      externalServices = listToAttrs (
        map (a: nameValuePair a { address = cfg.address; inherit port; }) cfg.aliases
      );
    };

    services.mysql = {
      enable = true;
      package = pkgs.mysql;
      bind = cfg.address;
      extraOptions = ''
        # Skip reverse DNS lookup of clients
        skip-name-resolve
      '';
    };

    systemd.services.mysql-bootstrap = {
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      wantedBy = [ "multi-user.target" ];
      after = [ "mysql.service" ];
      path = [ pkgs.mysql ];
      script = ''
        ${createDatabases cfg.databases}
      '';
    };

  };

}
