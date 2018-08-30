{ pkgs, cwPkgs, cwLibs, config, certs }:

with builtins;

rec {

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
                { name = "KUBERNETES_SERVICE_HOST"; value = "api.${config.networking.domain}"; }
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
                { name = "ETCD_ENDPOINTS"; value = "https://etcd.${config.networking.domain}:2379"; }
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
                { name = "ETCD_ENDPOINTS"; value = "https://etcd.${config.networking.domain}:2379"; }
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
                { name = "KUBERNETES_SERVICE_HOST"; value = "api.${config.networking.domain}"; }
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

}
