{ config, lib, pkgs, cwPkgs, cwLibs, ... }:

with builtins;
with lib;

let

  cfg = config.rabbitmq.k8s;
  port = 5672;

in {

  options = {

    rabbitmq.k8s = {

      enable = mkOption {
        type = types.bool;
        default = false;
      };

      name = mkOption {
        type = types.str;
        default = "rabbit";
      };

      address = mkOption {
        type = types.str;
        default = "169.254.1.50";
      };

      vhosts = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          List of rabbitmq vhosts to create. A user is created for
          each vhost.
        '';
      };

    };

  };

  imports = [
    ./infra_k8s.nix
  ];

  config = mkIf cfg.enable {

    infra.k8s = {
      externalServices = {
        "${cfg.name}" = { address = cfg.address; inherit port; };
      };
    };

    environment.etc = listToAttrs (map (v: {
      name = "consul.d/rabbitmq-${v}.json";
      value = {
        text = toJSON {
          service = {
            name = "${v}-queue";
            address = cfg.address;
            inherit port;
          };
        };
      };
    }) cfg.vhosts);

    services.rabbitmq = {
      enable = true;
      listenAddress = cfg.address;
    };

    systemd.services.rabbitmq-bootstrap = {
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "rabbitmq";
        Group = "rabbitmq";
      };
      wantedBy = [ "multi-user.target" ];
      after = [ "rabbitmq.service" ];
      path = with pkgs; [ rabbitmq_server ];
      script = ''
        ${concatStringsSep "\n" (map (v: ''
          rabbitmqctl add_user ${v} development
          rabbitmqctl add_vhost ${v}
          rabbitmqctl set_policy -p ${v} ha-all '^(?!amq\.).*' '{"ha-mode":"all"}'
          rabbitmqctl set_permissions -p ${v} ${v} '.*' '.*' '.*'
        '') cfg.vhosts)}
      '';
    };

  };

}
