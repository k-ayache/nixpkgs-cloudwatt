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
        bind 169.254.1.14
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
  kubePodPreset = toJSON {
    apiVersion = "settings.k8s.io/v1alpha1";
    kind = "PodPreset";
    metadata = {
      name = "vault-config";
    };
    spec = {
      env = [
        { name = "VAULT_ADDR"; value = "http://vault.localdomain:8200"; }
        { name = "CONSUL_LOG_LEVEL"; value = "debug"; }
        { name = "no_proxy"; value = "*"; }
      ];
    };
  };

  kube2consulDeployment = toJSON {
    apiVersion = "extensions/v1beta1";
    kind = "Deployment";
    metadata = { name = "kube2consul-worker"; };
    spec = {
      replicas = 1;
      template = {
        metadata = {
          labels = { application = "kube2consul"; service = "worker"; };
        };
        spec = {
          dnsPolicy = "Default";
          securityContext = { fsGroup = 65534; };
          containers = with cwPkgs.dockerImages; [
            {
              name = "kube2consul-worker";
              image = "${kube2consulWorker.imageName}:${kube2consulWorker.imageTag}";
              imagePullPolicy = "IfNotPresent";
              env = [
                { name = "KUBERNETES_SERVICE_HOST"; value = "api.${cfg.domain}"; }
                { name = "KUBERNETES_SERVICE_PORT"; value = "443"; }
                { name = "K2C_CONSUL_API"; value = "consul.localdomain:8500"; }
                { name = "K2C_LOGTOSTDERR"; value = "true"; }
              ];
              livenessProbe = cwLibs.mkHTTPGetProbe "/health" 8080 10 30 15;
              volumeMounts = [
                { mountPath = "/run/vault-token"; name = "vault-token"; }
                { mountPath = "/run/consul-template-wrapper"; name = "config"; }
              ];
            }
          ];
          volumes = [
            { name = "config"; emptyDir = {}; }
            {
              name = "vault-token";
              flexVolume = {
                driver = "cloudwatt/vaulttmpfs";
                options = { "vault/policies" = "kube2consul"; };
              };
            }
          ];
        };
      };
    };
  };

  calicoConfigMap = toJSON {
    kind = "ConfigMap";
    apiVersion = "v1";
    metadata = {
      name = "calico-config";
      namespace = "kube-system";
    };
    data = {
      etcd_ca = "/calico-secrets/etcd-ca";
      etcd_cert = "/calico-secrets/etcd-cert";
      etcd_key = "/calico-secrets/etcd-key";
      calico_backend = "bird";
    };
  };

  calicoSecrets = toJSON {
    apiVersion = "v1";
    kind = "Secret";
    type = "Opaque";
    metadata = {
      name = "calico-etcd-secrets";
      namespace = "kube-system";
    };
    data = {
      # Populate the following files with etcd TLS configuration if desired, but leave blank if
      # not using TLS for etcd.
      # This self-hosted install expects three files with the following names.  The values
      # should be base64 encoded strings of the entire contents of each file.
      etcd-ca = cwLibs.base64File "${certs.master}/ca.pem";
      etcd-cert = cwLibs.base64File "${certs.master}/etcd.pem";
      etcd-key = cwLibs.base64File "${certs.master}/etcd-key.pem";
    };
  };

  calicoNodeDaemonSet = toJSON {
    apiVersion = "extensions/v1beta1";
    kind = "DaemonSet";
    metadata = {
      name = "calico-node";
      namespace = "kube-system";
      labels = {
        k8s-app = "calico-node";
      };
    };
    spec = {
      selector = {
        matchLabels = {
          k8s-app = "calico-node";
        };
      };
      updateStrategy = {
        type = "RollingUpdate";
        rollingUpdate = {
          maxUnavailable = 1;
        };
      };
      template = {
        metadata = {
          labels = {
            k8s-app = "calico-node";
          };
          annotations = {
            "scheduler.alpha.kubernetes.io/critical-pod" = "";
          };
        };
        spec = {
          hostNetwork = true;
          tolerations = [
            # Make sure calico/node gets scheduled on all nodes.;
            { effect = "NoSchedule"; operator = "Exists"; }
            # Mark the pod as a critical add-on for rescheduling.;
            { key = "CriticalAddonsOnly"; operator = "Exists"; }
            { effect = "NoExecute"; operator = "Exists"; }
          ];
          serviceAccountName = "calico-node";
          # Minimize downtime during a rolling upgrade or deletion; tell Kubernetes to do a "force;
          # deletion" = https://kubernetes.io/docs/concepts/workloads/pods/pod/#termination-of-pods.;
          terminationGracePeriodSeconds = 0;
          containers = with cwPkgs.dockerImages.pulled; with cwLibs.image; [
            # Runs calico/node container on each Kubernetes node.  This;
            # container programs network policy and routes on each;
            # host.;
            {
              name = "calico-node";
              image = "${imageName calicoNodeImage}:${imageTag calicoNodeImage}";
              imagePullPolicy = "IfNotPresent";
              env = [
                # The location of the Calico etcd cluster.;
                { name = "ETCD_ENDPOINTS"; value = "https://etcd.${cfg.domain}:2379"; }
                # Choose the backend to use.;
                {
                  name = "CALICO_NETWORKING_BACKEND";
                  valueFrom = {
                    configMapKeyRef = { name = "calico-config"; key = "calico_backend"; };
                  };
                }
                # Cluster type to identify the deployment type;
                { name = "CLUSTER_TYPE"; value = "k8s,bgp"; }
                # Disable file logging so `kubectl logs` works.;
                { name = "CALICO_DISABLE_FILE_LOGGING"; value = "true"; }
                # Set noderef for node controller.;
                {
                  name = "CALICO_K8S_NODE_REF";
                  valueFrom = { fieldRef = { fieldPath = "spec.nodeName"; }; };
                }
                # Set Felix endpoint to host default action to ACCEPT.;
                { name = "FELIX_DEFAULTENDPOINTTOHOSTACTION"; value = "ACCEPT"; }
                # The default IPv4 pool to create on startup if none exists. Pod IPs will be;
                # chosen from this range. Changing this value after installation will have;
                # no effect. This should fall within `--cluster-cidr`.;
                { name = "CALICO_IPV4POOL_CIDR"; value = config.services.kubernetes.clusterCidr; }
                { name = "CALICO_IPV4POOL_IPIP"; value = "Always"; }
                # Disable IPv6 on Kubernetes.;
                { name = "FELIX_IPV6SUPPORT"; value = "false"; }
                # Set Felix logging to "info";
                { name = "FELIX_LOGSEVERITYSCREEN"; value = "info"; }
                # Set MTU for tunnel device used if ipip is enabled;
                { name = "FELIX_IPINIPMTU"; value = "1440"; }
                # Location of the CA certificate for etcd.;
                {
                  name = "ETCD_CA_CERT_FILE";
                  valueFrom = {
                    configMapKeyRef = { name = "calico-config"; key = "etcd_ca"; };
                  };
                }
                # Location of the client key for etcd.;
                {
                  name = "ETCD_KEY_FILE";
                  valueFrom = {
                    configMapKeyRef = { name = "calico-config"; key = "etcd_key"; };
                  };
                }
                # Location of the client certificate for etcd.;
                {
                  name = "ETCD_CERT_FILE";
                  valueFrom = {
                    configMapKeyRef = { name = "calico-config"; key = "etcd_cert"; };
                  };
                }
                # Auto-detect the BGP IP address.;
                { name = "IP"; value = "autodetect"; }
                { name = "FELIX_HEALTHENABLED"; value = "true"; }
              ];
              securityContext = {
                privileged = true;
              };
              livenessProbe = {
                httpGet = {
                  path = "/liveness";
                  port = 9099;
                };
                periodSeconds = 10;
                initialDelaySeconds = 10;
                failureThreshold = 6;
              };
              readinessProbe = {
                httpGet = {
                  path = "/readiness";
                  port = 9099;
                };
                periodSeconds = 10;
              };
              volumeMounts = [
                { mountPath = "/lib/modules"; name = "lib-modules"; readOnly = true; }
                { mountPath = "/var/run/calico"; name = "var-run-calico"; readOnly = false; }
                { mountPath = "/var/lib/calico"; name = "var-lib-calico"; readOnly = false; }
                { mountPath = "/calico-secrets"; name = "etcd-certs"; }
              ];
            }
          ];
          volumes = [
            # Used by calico/node.;
            { name = "lib-modules"; hostPath = { path = "/lib/modules"; }; }
            { name = "var-run-calico"; hostPath = { path = "/var/run/calico"; }; }
            { name = "var-lib-calico"; hostPath = { path = "/var/lib/calico"; }; }
            # Mount in the etcd TLS secrets with mode 400.;
            # See https =//kubernetes.io/docs/concepts/configuration/secret/;
            {
              name = "etcd-certs";
              secret = { secretName = "calico-etcd-secrets"; defaultMode = 0400; };
            }
          ];
        };
      };
    };
  };

  calicoKubeControllersDeployment = toJSON {
    apiVersion = "extensions/v1beta1";
    kind = "Deployment";
    metadata = {
      name = "calico-kube-controllers";
      namespace = "kube-system";
      labels = {
        k8s-app = "calico-kube-controllers";
      };
      annotations = {
        "scheduler.alpha.kubernetes.io/critical-pod" = "";
      };
    };
    spec = {
      # The controllers can only have a single active instance.;
      replicas = 1;
      strategy = {
        type = "Recreate";
      };
      template = {
        metadata = {
          name = "calico-kube-controllers";
          namespace = "kube-system";
          labels = {
            k8s-app = "calico-kube-controllers";
          };
        };
        spec = {
          # The controllers must run in the host network namespace so that;
          # it isn't governed by policy that would prevent it from working.;
          hostNetwork = true;
          tolerations = [
            # Mark the pod as a critical add-on for rescheduling.;
            { key = "CriticalAddonsOnly"; operator = "Exists"; }
            { key = "node-role.kubernetes.io/master"; effect = "NoSchedule"; }
          ];
          serviceAccountName = "calico-kube-controllers";
          securityContext = { fsGroup = 65534; };
          containers = with cwPkgs.dockerImages; [
            {
              name = "calico-kube-controllers";
              image = "${calicoKubeControllers.imageName}:${calicoKubeControllers.imageTag}";
              imagePullPolicy = "IfNotPresent";
              env = [
                # The location of the Calico etcd cluster.;
                { name = "ETCD_ENDPOINTS"; value = "https://etcd.${cfg.domain}:2379"; }
                # Location of the CA certificate for etcd.;
                {
                  name = "ETCD_CA_CERT_FILE";
                  valueFrom = {
                    configMapKeyRef = { name = "calico-config"; key = "etcd_ca"; };
                  };
                }
                # Location of the client key for etcd.;
                {
                  name = "ETCD_KEY_FILE";
                  valueFrom = {
                    configMapKeyRef = { name = "calico-config"; key = "etcd_key"; };
                  };
                }
                # Location of the client certificate for etcd.;
                {
                  name = "ETCD_CERT_FILE";
                  valueFrom = {
                    configMapKeyRef = { name = "calico-config"; key = "etcd_cert"; };
                  };
                }
                # Choose which controllers to run.;
                { name = "ENABLED_CONTROLLERS"; value = "policy,profile,workloadendpoint,node"; }
                { name = "KUBERNETES_SERVICE_HOST"; value = "api.${cfg.domain}"; }
              ];
              volumeMounts = [
                # Mount in the etcd TLS secrets.;
                { mountPath = "/calico-secrets"; name = "etcd-certs"; }
              ];
            }
          ];
          volumes = [
            # Mount in the etcd TLS secrets with mode 400.;
            # See https =//kubernetes.io/docs/concepts/configuration/secret/;
            {
              name = "etcd-certs";
              secret = { secretName = "calico-etcd-secrets"; defaultMode = 0400; };
            }
          ];
        };
      };
    };
  };

  calicoKubeControllersServiceAccount = toJSON {
    apiVersion = "v1";
    kind = "ServiceAccount";
    metadata = {
      name = "calico-kube-controllers";
      namespace = "kube-system";
    };
  };

  calicoNodeServiceAccount = toJSON {
    apiVersion = "v1";
    kind = "ServiceAccount";
    metadata = {
      name = "calico-node";
      namespace = "kube-system";
    };
  };

  certs = import (pkgs.path + /nixos/tests/kubernetes/certs.nix) {
    inherit pkgs;
    internalDomain = cfg.domain;
    externalDomain = cfg.domain;
    kubelets = [ config.networking.hostName ];
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
      postStart = ''
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
      after = [ "consul.service" "kube-apiserver.service" "kubelet-bootstrap.service" ];
      path = with pkgs; [ kubectl docker cwPkgs.waitFor ];
      script = ''
        wait-for localhost:8080 -q -t 300
        # give cluster-admin role to all accounts
        kubectl create clusterrolebinding permissive-binding \
          --clusterrole=cluster-admin \
          --user=admin \
          --user=kubelet \
          --group=system:serviceaccounts
        kubectl apply -f /etc/kubernetes/infra
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
      "kubernetes/infra/kube2consul.json".text = kube2consulDeployment;
      "kubernetes/infra/pod-preset.json".text = kubePodPreset;
      "kubernetes/infra/calico-config-map.json".text = calicoConfigMap;
      "kubernetes/infra/calico-secrets.json".text = calicoSecrets;
      "kubernetes/infra/calico-node.daemonset.json".text = calicoNodeDaemonSet;
      "kubernetes/infra/calico-node.serviceaccount.json".text = calicoNodeServiceAccount;
      "kubernetes/infra/calico-kube-controllers.deployment.json".text = calicoKubeControllersDeployment;
      "kubernetes/infra/calico-kube-controllers.serviceaccount.json".text = calicoKubeControllersServiceAccount;
      "kubernetes/volumeplugins/cloudwatt~vaulttmpfs/vaulttmpfs".source =
        "${cwPkgs.vaulttmpfs}/bin/kubernetes-flexvolume-vault-plugin";
    } // (mapAttrs' (name: { address, port }:
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
