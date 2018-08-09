{ lib, pkgs, cwPkgs }:

with builtins;
with pkgs.lib;

let

  recursiveUpdateUntil' = pred: lhs: rhs:
    let f = attrPath:
      zipAttrsWith (n: values:
        if tail values == [] || pred attrPath (head (tail values)) (head values) then
          if length values == 2 && isList (head values) && isList (head (tail values)) then
            flatten values
          else
            head values
        else
          f (attrPath ++ [n]) values
      );
    in f [] [rhs lhs];

  # version of recursiveUpdate that will concat list values
  # instead of just taking the rhs list
  recursiveUpdate' = lhs: rhs:
    recursiveUpdateUntil' (path: lhs: rhs:
      !(isAttrs lhs && isAttrs rhs)
    ) lhs rhs;

  containerTemplate = { application, service, port, vaultPolicy }: {
    name = "${application}-${service}";
    imagePullPolicy = "IfNotPresent";
    env = envTemplate application service;
    volumeMounts = volumeMountsTemplate vaultPolicy;
  } // optionalAttrs (port != 0) {
    ports = [ { containerPort = port; } ];
  };

  envTemplate = application: service: [
    {
      name = "openstack_region";
      valueFrom = {
        configMapKeyRef = {
          name = "openstack";
          key = "region";
        };
      };
    }
    {
      name = "application";
      value = application;
    }
    {
      name = "service";
      value = service;
    }
  ];

  volumeMountsTemplate = vaultPolicy: [
    { name = "config"; mountPath = "/run/consul-template-wrapper"; }
  ] ++ optional (vaultPolicy != "") { name = "vault-token"; mountPath = "/run/vault-token"; };

  volumesTemplate = vaultPolicy: [
    { name = "config"; emptyDir = {}; }
  ] ++ optional (vaultPolicy != "")
    {
      name = "vault-token";
      flexVolume = {
        driver = "cloudwatt/vaulttmpfs";
        options = {
          "vault/policies" = vaultPolicy;
        };
      };
    };

in rec {

  mkHTTPGetProbe = path: port: initial: period: timeout: {
    httpGet = { inherit path port; };
    initialDelaySeconds = initial;
    periodSeconds = period;
    timeoutSeconds = timeout;
  };

  mkDeployment = { application, service, replicas ? 1, port ? 0, vaultPolicy ? "", containers, volumes ? [] }: {
    apiVersion = "extensions/v1beta1";
    kind = "Deployment";
    metadata = {
      name = "${application}-${service}";
    };
    spec = {
      replicas = replicas;
      template = {
        metadata = {
          labels = {
            application = application;
            service = service;
          };
        };
        spec = {
          dnsPolicy = "Default";
          terminationGracePeriodSeconds = 1200;
          containers = map (c:
            (recursiveUpdate' (containerTemplate { inherit application service port vaultPolicy; }) c)
          ) containers;
          volumes = (volumesTemplate vaultPolicy) ++ volumes;
        };
      };
    };
  };

  # Allows to override all parts of the deployment by passing a second attrs
  mkDeployment' = args: override: recursiveUpdate' (mkDeployment args) override;

  mkJSONDeployment = args: toJSON (mkDeployment args);

  mkJSONDeployment' = args: override: toJSON (mkDeployment' args override);

  mkService = { application, service, selector ? {}}: {
    apiVersion = "v1";
    kind = "Service";
    metadata = {
      name = "${application}-${service}";
    };
    spec = {
      clusterIP = null;
      ports = [
        { port = 1; }
      ];
    }
    // optionalAttrs (selector != {}) { inherit selector; }
    // optionalAttrs (selector == {}) {
      selector = {
        application = application;
        service = service;
      };
    };
  };

  mkJSONService = args: toJSON (mkService args);

}
