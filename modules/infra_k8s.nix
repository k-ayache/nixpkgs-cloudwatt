{ config, lib, pkgs, cwPkgs, cwLibs, ... }:

with builtins;
with lib;

let
  cfg = config.infra.k8s;

  vaultRootToken = "development";
  vaultTmpfsToken = "vaulttmpfs";

  defaultVaultData = {
    "secret/kube2consul" = {
      consul_token = "dummy";
    };
  };

  defaultVaultPolicies = {
    admin = {
      "*" = {
        capabilities = [ "create" "read" "update" "delete" "list" "sudo" ];
      };
    };
    applications_token_creator = {
      "auth/token/create/applications" = {
        capabilities = [ "create" "read" "update" "delete" "list" ];
      };
      "auth/token/roles" = {
        capabilities = [ "read" "list" ];
      };
      "auth/token/roles/applications" = {
        capabilities = [ "read" ];
      };
    };
    kube2consul = {
      "secret/kube2consul" = {
        policy = "read";
      };
    };
  };

  defaultVaultRoles = {
    applications = {
      disallowed_policies = "admin";
      explicit_max_ttl = 0;
      name = "applications";
      orphan = true;
      path_suffix = "";
      period = "1h";
      renewable = true;
    };
  };

  certs = import (pkgs.path + /nixos/tests/kubernetes/certs.nix) {
    inherit pkgs;
    internalDomain = cfg.domain;
    externalDomain = cfg.domain;
    kubelets = [ config.networking.hostName ];
  };

  infraConfig = import ./config/infra_k8s.nix { inherit pkgs cwPkgs cwLibs config certs; };
  infraLib = import ./lib/infra_k8s.nix { inherit pkgs; };

in {

  options = {
    infra.k8s = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };

      domain = mkOption {
        type = types.str;
        default = "dev0.loc.cloudwatt.net";
        description = ''
          Domain that will be used for the k8s cluster.
        '';
      };

      masterIP = mkOption {
        type = types.str;
        default = "192.168.1.1";
        description = ''
          The ip of the machine that will run the k8s cluster.
        '';
      };

      seedDockerImages = mkOption {
        description = "List of docker images to preload on system";
        default = [];
        type = types.listOf types.package;
      };

      externalServices = mkOption {
        type = types.attrsOf types.attrs;
        default = {};
        description = ''
          Allow to pass a list of services definitions that will be
          integrated in the infra.

          The ip address will be added to the loopback interface.
          The service will be registered in consul.

          Example:

            {
              cassandra = {
                address = "169.254.1.100";
                port = 9160;
              };
            };

        '';
      };

      consulData = mkOption {
        type = types.attrsOf types.attrs;
        default = {};
        description = ''
          Data that will be injected in the consul server.
          Key is the path, value is an attrs that will be
          converted to JSON.
        '';
      };

      vaultData = mkOption {
        type = types.attrsOf types.attrs;
        default = {};
        description = ''
          Data that will be injected in vault at a given path.

          Example:

            {
              "secret/service" = {
                password = "foo";
              };
            };

        '';
      };

      vaultPolicies = mkOption {
        type = types.attrsOf types.attrs;
        default = {};
        description = ''
          Policies to be injected in vault.

          Example:

            service = {
              "secret/service" = {
                policy = "read";
              };
            };

        '';
      };

      vaultRoles = mkOption {
        type = types.attrsOf types.attrs;
        default = {};
        description = ''
          Roles to be injected in vault.

          Example:

            {
              my-role = {
                disallowed_policies = "admin";
                explicit_max_ttl = 0;
                name = "my-role";
                orphan = true;
                path_suffix = "";
                period = "1h";
                renewable = true;
              };
            };

        '';
      };

    };
  };

  config = mkIf cfg.enable {

    networking = {
      firewall.enable = false;
      domain = cfg.domain;
      hosts = {
        "127.0.2.1" = [ "etcd.${cfg.domain}" "etcd" ];
        "169.254.1.10" = [ "resolver.localdomain" "resolver" ];
        "169.254.1.11" = [ "consul.localdomain" "consul" ];
        "169.254.1.12" = [ "api.localdomain" "api.${cfg.domain}" "api" ];
        "169.254.1.13" = [ "vault.localdomain" "vault" ];
        "169.254.1.14" = [ "fluentd.localdomain" "fluentd" ];
        "${cfg.masterIP}" = [ "${config.networking.hostName}.${cfg.domain}" config.networking.hostName ];
      } // mapAttrs' (name: { address, ... }: nameValuePair address [ "${name}.localdomain" name ])
        cfg.externalServices;
      interfaces.lo.ipv4.addresses = [
        { address = "169.254.1.10"; prefixLength = 32; }
        { address = "169.254.1.11"; prefixLength = 32; }
        { address = "169.254.1.12"; prefixLength = 32; }
        { address = "169.254.1.13"; prefixLength = 32; }
        { address = "169.254.1.14"; prefixLength = 32; }
      ] ++ mapAttrsToList (name: { address, ... }: { inherit address; prefixLength = 32; }) cfg.externalServices;
    };

    services.etcd = {
      enable = true;
      certFile = "${certs.master}/etcd.pem";
      keyFile = "${certs.master}/etcd-key.pem";
      trustedCaFile = "${certs.master}/ca.pem";
      peerClientCertAuth = false;
      listenClientUrls = ["https://0.0.0.0:2379"];
      listenPeerUrls = ["https://0.0.0.0:2380"];
      advertiseClientUrls = ["https://etcd.${cfg.domain}:2379"];
      initialCluster = ["${config.networking.hostName}=https://etcd.${cfg.domain}:2380"];
      initialAdvertisePeerUrls = ["https://etcd.${cfg.domain}:2380"];
    };

    # dnsmasq will bind on all interfaces because it
    # sets 127.0.0.1 in resolv.conf
    services.dnsmasq = {
      enable = true;
      extraConfig = ''
        bind-interfaces
        no-negcache
        server=/localdomain/
        server=/node.${cfg.domain}/169.254.1.11#8600
        server=/query.${cfg.domain}/169.254.1.11#8600
        server=/service.${cfg.domain}/169.254.1.11#8600
      '';
    };

    services.kubernetes = {
      roles = ["master" "node"];
      verbose = false;
      clusterCidr = "10.1.0.0/16";
      caFile = "${certs.master}/ca.pem";
      etcd = {
        servers = ["https://etcd.${cfg.domain}:2379"];
        certFile = "${certs.worker}/etcd-client.pem";
        keyFile = "${certs.worker}/etcd-client-key.pem";
      };
      apiserver = {
        tlsCertFile = "${certs.master}/kube-apiserver.pem";
        tlsKeyFile = "${certs.master}/kube-apiserver-key.pem";
        kubeletClientCertFile = "${certs.master}/kubelet-client.pem";
        kubeletClientKeyFile = "${certs.master}/kubelet-client-key.pem";
        serviceAccountKeyFile = "${certs.master}/kube-service-accounts.pem";
        # enable PodPreset api
        runtimeConfig = "authentication.k8s.io/v1beta1=true,settings.k8s.io/v1alpha1=true";
        admissionControl = [ "NamespaceLifecycle" "LimitRanger" "ServiceAccount" "ResourceQuota" "DefaultStorageClass" "DefaultTolerationSeconds" "NodeRestriction" "PodPreset" ];
      };
      kubeconfig = {
        server = "https://api.${cfg.domain}";
      };
      kubelet = {
        tlsCertFile = "${certs.worker}/kubelet.pem";
        tlsKeyFile = "${certs.worker}/kubelet-key.pem";
        hostname = "${config.networking.hostName}.${cfg.domain}";
        kubeconfig = {
          certFile = "${certs.worker}/apiserver-client-kubelet-${config.networking.hostName}.pem";
          keyFile = "${certs.worker}/apiserver-client-kubelet-${config.networking.hostName}-key.pem";
        };
        networkPlugin = "cni";
        cni = {
          packages = [ cwPkgs.cni_0_3_0 cwPkgs.calicoCniPlugin ];
          config = [
            {
              name = "calico-k8s-network";
              cniVersion = "0.3.0";
              type = "calico";
              etcd_endpoints = "https://etcd.${cfg.domain}:2379";
              etcd_key_file = "${certs.master}/etcd-key.pem";
              etcd_cert_file = "${certs.master}/etcd.pem";
              etcd_ca_cert_file = "${certs.master}/ca.pem";
              log_level = "INFO";
              ipam = {
                type = "calico-ipam";
              };
              policy = {
                type = "k8s";
              };
              kubernetes = {
                kubeconfig = pkgs.writeText "cni-kubeconfig" (builtins.toJSON {
                  apiVersion = "v1";
                  kind = "Config";
                  clusters = [{
                    name = "local";
                    cluster.certificate-authority = "${certs.master}/ca.pem";
                    cluster.server = "https://api.${cfg.domain}";
                  }];
                  users = [{
                    name = "kubelet";
                    user = {
                      client-certificate =
                        "${certs.worker}/apiserver-client-kubelet-${config.networking.hostName}.pem";
                      client-key =
                        "${certs.worker}/apiserver-client-kubelet-${config.networking.hostName}-key.pem";
                    };
                  }];
                  contexts = [{
                    context = { cluster = "local"; user = "kubelet"; };
                    current-context = "kubelet-context";
                  }];
                });
              };
            }
            {
              name = "loopback";
              cniVersion = "0.3.0";
              type = "loopback";
            }
          ];
        };
        extraOpts = "--resolv-conf=/etc/kubernetes/kubelet/resolv.conf --volume-plugin-dir=/etc/kubernetes/volumeplugins";
        seedDockerImages = with cwPkgs.dockerImages; [
          kube2consulWorker
          pulled.calicoNodeImage
          calicoKubeControllers
        ] ++ cfg.seedDockerImages;
      };
      controllerManager = {
        serviceAccountKeyFile = "${certs.master}/kube-service-accounts-key.pem";
        kubeconfig = {
          certFile = "${certs.master}/apiserver-client-kube-controller-manager.pem";
          keyFile = "${certs.master}/apiserver-client-kube-controller-manager-key.pem";
        };
      };
      scheduler = {
        kubeconfig = {
          certFile = "${certs.master}/apiserver-client-kube-scheduler.pem";
          keyFile = "${certs.master}/apiserver-client-kube-scheduler-key.pem";
        };
      };
      proxy = {
        enable = false;
        kubeconfig = {
          certFile = "${certs.worker}/apiserver-client-kube-proxy.pem";
          keyFile = "${certs.worker}/apiserver-client-kube-proxy-key.pem";
        };
      };
      addonManager.enable = false;
      addons.dns.enable = false;
    };

    systemd.services.kubelet = {
      # For vaulttmpfs
      environment = {
        VAULTTMPFS_GENERATOR_TOKEN_PATH = pkgs.writeText "token" vaultTmpfsToken;
        VAULT_WRAP_TTL = "5m";
        VAULT_ADDR = "http://vault.localdomain:8200";
      };
      serviceConfig = {
        # https://github.com/NixOS/nixpkgs/issues/44263
        CPUAccounting = true;
        MemoryAccounting = true;
      };
    };

    systemd.services.vault = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      # vault needs glibc for getent binary
      path = with pkgs; [ vault glibc cwPkgs.waitFor ];
      script = ''
        vault server -dev -dev-listen-address=169.254.1.13:8200 -dev-root-token-id=${vaultRootToken}
      '';
      postStart = with infraLib; ''
        wait-for vault.localdomain:8200 -q
        # wait for complete unseal
        sleep 5
        export VAULT_ADDR=http://vault.localdomain:8200
        ${createVaultPolicies (recursiveUpdate defaultVaultPolicies cfg.vaultPolicies)}
        ${writeVaultPaths "auth/token/roles/" (defaultVaultRoles // cfg.vaultRoles)}
        ${writeVaultPaths "" (defaultVaultData // cfg.vaultData)}
        # create token for vaulttmpfs
        vault token create -orphan -period=86400 -renewable=true -policy=applications_token_creator -metadata="applications=kubernetes-flexvolume-vault-plugin" -id ${vaultTmpfsToken}
      '';
    };

    systemd.services.fluentd = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      script = "${cwPkgs.fluentdCw}/bin/fluentd --no-supervisor -q -c ${infraConfig.fluentdConf}";
    };

    systemd.services.consul = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      path = with pkgs; [ consul cwPkgs.waitFor curl ];
      script = ''
        consul agent -dev -log-level info -client 169.254.1.11 -domain ${cfg.domain} -config-dir /etc/consul.d
      '';
      postStart = ''
        wait-for consul.localdomain:8500 -q
        ${concatStringsSep "\n"
          (mapAttrsToList (name: data:
            let dataFile = pkgs.writeText "${replaceStrings [ "/" ] [ "_" ] name}.json" (toJSON data);
            in "curl -X PUT -d @${dataFile} http://consul.localdomain:8500/v1/kv/${name}") cfg.consulData)}
      '';
    };

    systemd.services.kube-bootstrap = {
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      wantedBy = [ "kubernetes.target" ];
      after = [ "vault.service" "consul.service" "kube-apiserver.service" "kubelet-bootstrap.service" ];
      path = with pkgs; [ kubectl docker cwPkgs.waitFor ];
      script = ''
        wait-for localhost:8080 -q -t 300
        # give cluster-admin role to all accounts
        kubectl create clusterrolebinding permissive-binding \
          --clusterrole=cluster-admin \
          --user=admin \
          --user=kubelet \
          --group=system:serviceaccounts
        kubectl apply -f /etc/kubernetes/openstack
        kubectl apply -f /etc/kubernetes/infra/stage1
        while [ $(kubectl --namespace kube-system get pods --field-selector=status.phase=Running 2>/dev/null | wc -l) -ne 3 ]
        do
          echo "Waiting on calico to be ready..."
          sleep 1
        done
        kubectl apply -f /etc/kubernetes/infra/stage2
      '';
    };

    environment.etc = with infraConfig; {
      "docker/daemon.json".text = ''
        {
          "dns-opts": ["ndots:2"]
        }
      '';
      # provides our DNS to pods so that they can resolve
      # consul and local services.
      "kubernetes/kubelet/resolv.conf".text = ''
        search ${cfg.domain}
        nameserver 169.254.1.10
        options timeout:1
      '';
      "kubernetes/openstack/configmap.yml".source = kubeConfigMap;
      # prodPreset to configure consul-template-wrapper
      "kubernetes/infra/stage1/pod-preset.json".text = kubePodPreset;
      # calico config to be applied in the cluster
      "kubernetes/infra/stage1/calico-config-map.json".text = calicoConfigMap;
      "kubernetes/infra/stage1/calico-secrets.json".text = calicoSecrets;
      "kubernetes/infra/stage1/calico-node.serviceaccount.json".text = calicoNodeServiceAccount;
      "kubernetes/infra/stage1/calico-kube-controllers.serviceaccount.json".text =
        calicoKubeControllersServiceAccount;
      # deployment of calico
      "kubernetes/infra/stage1/calico-node.daemonset.json".text = calicoNodeDaemonSet;
      "kubernetes/infra/stage1/calico-kube-controllers.deployment.json".text =
        calicoKubeControllersDeployment;
      # kube2consul deployment
      "kubernetes/infra/stage2/kube2consul.json".text = kube2consulDeployment;
      # vaulttmpfs plugin must be placed in a special directory tree so that the kubelet can
      # find it. This directory is passed to the kubelet with the --volume-plugin-dir flag.
      "kubernetes/volumeplugins/cloudwatt~vaulttmpfs/vaulttmpfs".source =
        "${cwPkgs.vaulttmpfs}/bin/kubernetes-flexvolume-vault-plugin";
    }
    # add host services in consul
    // (mapAttrs' (name: { address, port }:
      nameValuePair "consul.d/${name}.json" { text = toJSON { service = { inherit name port address; }; }; }
    ) cfg.externalServices);

    environment.systemPackages = with pkgs; [
      jq
      kubectl
      docker
      vault
    ];

    environment.variables = {
      TERM = "xterm";
      # this is for using vault on the host
      VAULT_ADDR = "http://vault.localdomain:8200";
    };

  };

}
