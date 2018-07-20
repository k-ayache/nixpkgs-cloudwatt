{ config, lib, pkgs, cwPkgs, cwLibs, ... }:

with builtins;
with lib;

let
  cfg = config.infra.k8s;

  vaultRootToken = "development";
  vaultTmpfsToken = "vaulttmpfs";

  defaultVaultData = {};

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

  # transform data to hcl format
  # https://www.vaultproject.io/intro/getting-started/policies.html
  generateVaultPolicy = policy:
  concatStringsSep "\n" (mapAttrsToList (path: data: ''path "${path}" {
    ${concatStringsSep ",\n" (mapAttrsToList (key: value: "${key} = ${toJSON value}") data)}
}'') policy);

  generateVaultPolicies = policies:
    mapAttrs (name: policy: generateVaultPolicy policy) policies;

  createVaultPolicies = policies:
    concatStringsSep "\n" (mapAttrsToList (name: policy: ''
      vault policy write ${name} -<<EOF
      ${policy}
      EOF
    '') (generateVaultPolicies policies));

  # generate vault write command from attrs
  writeVaultPath = prefix: path: datas:
    let
      jsonData = pkgs.writeText "${replaceStrings ["/"] ["_"] path}.json" (toJSON datas);
    in
      "cat ${jsonData} | vault write ${prefix}${path} -";

  writeVaultPaths = prefix: paths:
    concatStringsSep "\n" (mapAttrsToList (writeVaultPath prefix) paths);

  fluentdConf = pkgs.writeTextFile {
    name = "fluentd.conf";
    text = ''
      <source>
        @type forward
        bind 169.254.1.15
        port 24224
      </source>
      <match **>
        @type stdout
      </match>
    '';
  };

  # Set the VAULT_ADDR variable for all pods
  # Also sets no_proxy variable to not use hard coded https_proxy in consul-template-wrapper
  # This is applied by the kube-bootstrap service
  kubePodPreset = cwLibs.writeYamlFile {
    name = "pod-preset.yml";
    text = ''
      ---
      apiVersion: settings.k8s.io/v1alpha1
      kind: PodPreset
      metadata:
        name: set-vault-token
      spec:
        env:
          - name: VAULT_ADDR
            value: "http://vault.localdomain:8200"
          - name: no_proxy
            value: "*"
    '';
  };

  kube2consulImage = cwLibs.buildImageWithPerp {
    name = "kube2consul/worker";
    fromImage = cwLibs.images.kubernetesBaseImage;
    environmentFile = pkgs.writeText "env" ''
      KUBERNETES_SERVICE_HOST=api.${cfg.domain}
      KUBERNETES_SERVICE_PORT=443
      K2C_CONSUL_API=consul.localdomain:8500
    '';
    command = "${cwPkgs.kube2consul}/bin/kube2consul -lock";
  };

  kube2consulDeployment = cwLibs.writeYamlFile {
    name = "deployment.yml";
    text = ''
      ---
      apiVersion: extensions/v1beta1
      kind: Deployment
      metadata:
        name: kube2consul-worker
      spec:
        replicas: 1
        template:
          metadata:
            labels:
              application: kube2consul
              service: worker
          spec:
            dnsPolicy: Default
            containers:
              - name: kube2consul-worker
                image: ${kube2consulImage.imageName}:${kube2consulImage.imageTag}
                imagePullPolicy: IfNotPresent
                env:
                  - name: K2C_LOGTOSTDERR
                    value: "true"
                volumeMounts:
                  - mountPath: /run/vault-token
                    name: vault-token
                  - mountPath: /run/consul-template-wrapper
                    name: config
            volumes:
              - emptyDir:
                name: config
              - flexVolume:
                  driver: cloudwatt/vaulttmpfs
                  fsType: tmpfs
                  options:
                    vault/policies: kube2consul
                name: vault-token
    '';
  };

  certs = import (pkgs.path + /nixos/tests/kubernetes/certs.nix) {
    inherit pkgs;
    internalDomain = cfg.domain;
    externalDomain = cfg.domain;
    kubelets = [ cfg.masterName ];
  };

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

      masterName = mkOption {
        type = types.str;
        default = "machine";
        description = ''
          The name of the machine that will run the k8s cluster.
        '';
      };

      rabbitmqVhosts = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          List of rabbitmq vhosts to create. A user is created for
          each vhost.
          If the list is empty, rabbitmq is not started.
        '';
      };

      externalServices = mkOption {
        type = types.listOf types.attrs;
        default = [];
        description = ''
          Allow to pass a list of services definitions that will be
          integrated in the infra.
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

  config = mkIf cfg.enable (mkMerge [{

    networking = {
      firewall.enable = false;
      domain = cfg.domain;
      hosts = {
        "127.0.2.1" = [ "etcd.${cfg.domain}" "etcd" ];
        "169.254.1.10" = [ "resolver.localdomain" "resolver" ];
        "169.254.1.11" = [ "consul.localdomain" "consul" ];
        "169.254.1.12" = [ "api.localdomain" "api.${cfg.domain}" "api" ];
        "169.254.1.13" = [ "vault.localdomain" "vault" ];
        "169.254.1.14" = [ "rabbit.localdomain" "rabbit" ];
        "169.254.1.15" = [ "fluentd.localdomain" "fluentd" ];
        "${cfg.masterIP}" = [ "${cfg.masterName}.${cfg.domain}" cfg.masterName ];
      } // listToAttrs (map ({ address, name, ... }:
        { name = address; value = [ "${name}.localdomain" name ];}) cfg.externalServices);
      interfaces.lo.ipv4.addresses = [
        { address = "169.254.1.10"; prefixLength = 32; }
        { address = "169.254.1.11"; prefixLength = 32; }
        { address = "169.254.1.12"; prefixLength = 32; }
        { address = "169.254.1.13"; prefixLength = 32; }
        { address = "169.254.1.14"; prefixLength = 32; }
        { address = "169.254.1.15"; prefixLength = 32; }
      ] ++ map ({ address, ... }: { inherit address; prefixLength = 32; }) cfg.externalServices;
    };

    services.etcd = {
      enable = true;
      certFile = "${certs.master}/etcd.pem";
      keyFile = "${certs.master}/etcd-key.pem";
      trustedCaFile = "${certs.master}/ca.pem";
      peerClientCertAuth = true;
      listenClientUrls = ["https://0.0.0.0:2379"];
      listenPeerUrls = ["https://0.0.0.0:2380"];
      advertiseClientUrls = ["https://etcd.${cfg.domain}:2379"];
      initialCluster = ["${cfg.masterName}=https://etcd.${cfg.domain}:2380"];
      initialAdvertisePeerUrls = ["https://etcd.${cfg.domain}:2380"];
    };

    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false;
      extraConfig = ''
        listen-address=169.254.1.10
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
        extraOpts = "--resolv-conf=/etc/kubernetes/kubelet/resolv.conf --volume-plugin-dir=/etc/kubernetes/volumeplugins";
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
      postStart = ''
        wait-for vault.localdomain:8200 -q
        # wait for complete unseal
        sleep 5
        export VAULT_ADDR=http://vault.localdomain:8200
        ${createVaultPolicies (recursiveUpdate defaultVaultPolicies cfg.vaultPolicies)}
        ${writeVaultPaths "auth/token/roles/" (defaultVaultRoles // cfg.vaultRoles)}
        ${writeVaultPaths "" (defaultVaultData // cfg.vaultData)}
        # create token for vaulttmpfs
        vault token create -orphan -metadata="node=${cfg.masterName}" -period=86400 -renewable=true -policy=applications_token_creator -metadata="applications=kubernetes-flexvolume-vault-plugin" -id ${vaultTmpfsToken}
      '';
    };

    systemd.services.fluentd = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      script = "${cwPkgs.fluentdCw}/bin/fluentd --no-supervisor -q -c ${fluentdConf}";
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
      after = [ "consul.service" "kube-apiserver.service" ];
      path = [ pkgs.kubectl pkgs.docker cwPkgs.waitFor ];
      script = ''
        wait-for localhost:8080 -q -t 300
        # give cluster-admin role to all accounts
        kubectl create clusterrolebinding permissive-binding \
          --clusterrole=cluster-admin \
          --user=admin \
          --user=kubelet \
          --group=system:serviceaccounts
        # set vault token in all pods
        kubectl apply -f /etc/kubernetes/infra/pod-preset.yml
        # deploy kube2consul
        docker load -i ${kube2consulImage}
        kubectl apply -f /etc/kubernetes/infra/kube2consul.yml
      '';
    };

    environment.etc = {
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
      "kubernetes/infra/kube2consul.yml".source = kube2consulDeployment;
      "kubernetes/infra/pod-preset.yml".source = kubePodPreset;
      "kubernetes/volumeplugins/cloudwatt~vaulttmpfs/vaulttmpfs".source = "${cwPkgs.vaulttmpfs}/bin/kubernetes-flexvolume-vault-plugin";
    } // listToAttrs (map ({ address, name, port }: {
      name = "consul.d/${name}.json";
      value = {
        text = toJSON {
          service = { inherit name port address; };
        };
      };
    }) cfg.externalServices);

    environment.variables = {
      TERM = "xterm";
      # this is for using vault on the host
      VAULT_ADDR = "http://vault.localdomain:8200";
    };

  } (mkIf (cfg.rabbitmqVhosts != []) {

    services.rabbitmq = {
      enable = true;
      listenAddress = "169.254.1.14";
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
        '') cfg.rabbitmqVhosts)}
      '';
    };

    environment.etc = listToAttrs (map (v: {
      name = "consul.d/rabbitmq-${v}.json";
      value = {
        text = toJSON {
          service = {
            name = "${v}-queue";
            address = "169.254.1.14";
            port = 5672;
          };
        };
      };
    }) cfg.rabbitmqVhosts);

  })]);

}
