{ pkgs
, cwPkgs
, lib
, stdenv
}:

with import (pkgs.path + /nixos/lib/testing.nix) { system = builtins.currentSystem; };

let

  service1 = pkgs.writeShellScriptBin "service1" ''
    while true
    do
      echo "service1"
      sleep 1
    done
  '';

  service1Image = lib.buildImageWithPerps {
    name = "test/service1";
    fromImage = lib.images.kubernetesBaseImage;
    services = [
      {
        name = "service1";
        command = "${service1}/bin/service1";
        fluentd = {
          source = {
            type = "stdout";
          };
        };
      }
    ];
  };

  service1Deployment = lib.writeYamlFile {
    name = "deployment.yml";
    text = ''
      ---
      apiVersion: extensions/v1beta1
      kind: Deployment
      metadata:
        name: service1-pods
      spec:
        replicas: 1
        template:
          metadata:
            labels:
              application: test
              service: service1
          spec:
            dnsPolicy: Default
            containers:
              - name: service1
                image: ${service1Image.imageName}:${service1Image.imageTag}
                imagePullPolicy: IfNotPresent
    '';
  };

  service1Service = lib.writeYamlFile {
    name = "service.yml";
    text = ''
      ---
      apiVersion: v1
      kind: Service
      metadata:
        name: service1-pods
      spec:
        clusterIP: None
        selector:
          application: test
          service: service1
        ports:
          - port: 1
    '';
  };

  service2 = pkgs.writeShellScriptBin "service2" ''
    while true
    do
      echo "service2"
      sleep 1
    done
  '';

  service2Template = pkgs.writeTextFile {
    name = "template";
    text = ''
      {{ $service2 := key "/service2" | parseJSON -}}
      {{ $service2.data }}
	  {{- with secret "secret/service2" -}}
		{{ .Data.password }}
	  {{- end }}
    '';
  };

  service2Image = lib.buildImageWithPerps {
    name = "test/service2";
    fromImage = lib.images.kubernetesBaseImage;
    services = [
      {
        name = "service2";
        command = "${service2}/bin/service2";
        preStartScript = ''
          consul-template-wrapper --no-lock -- -once \
            -template "${service2Template}:/run/consul-template-wrapper/result"
        '';
      }
    ];
  };

  service2Deployment = lib.writeYamlFile {
    name = "deployment.yml";
    text = ''
      ---
      apiVersion: extensions/v1beta1
      kind: Deployment
      metadata:
        name: service2-pods
      spec:
        replicas: 1
        template:
          metadata:
            labels:
              application: test
              service: service2
          spec:
            dnsPolicy: Default
            securityContext:
              fsGroup: 65534
            containers:
              - name: service2
                image: ${service2Image.imageName}:${service2Image.imageTag}
                imagePullPolicy: IfNotPresent
                volumeMounts:
                  - name: vault-token
                    mountPath: /run/vault-token
            volumes:
              - name: vault-token
                flexVolume:
                  driver: cloudwatt/vaulttmpfs
                  options:
                    vault/policies: service2
    '';
  };

  service2Service = lib.writeYamlFile {
    name = "service.yml";
    text = ''
      ---
      apiVersion: v1
      kind: Service
      metadata:
        name: service2-pods
      spec:
        clusterIP: None
        selector:
          application: test
          service: service2
        ports:
          - port: 1
    '';
  };

  master = { config, ... }: {

    imports = [
      ../modules/infra_k8s.nix
      ../modules/rabbitmq_k8s.nix
    ];

    config = {
      _module.args = { inherit cwPkgs; cwLibs = lib; };

      services.openssh.enable = true;
      services.openssh.permitRootLogin = "yes";
      services.openssh.extraConfig = "PermitEmptyPasswords yes";
      users.extraUsers.root.password = "";

      infra.k8s = {
        enable = true;
        masterName = "master";
        externalServices = {
          foo = {
            address = "169.254.1.100";
            port = 2222;
          };
        };
        consulData = {
          service2 = {
            data = "foo";
          };
        };
        vaultData = {
          "secret/service2" = {
            password = "plop";
          };
        };
        vaultPolicies = {
          "service2" = {
            "secret/service2" = {
              policy = "read";
            };
          };
        };
      };

      rabbitmq.k8s = {
        enable = true;
        vhosts = [ "foo" ];
      };

      virtualisation = {
        diskSize = 10000;
        memorySize = 2048;
        cores = 2;
      };

      # # forward some ports on the host for debugging
      # virtualisation.qemu.networkingOptions = [
      #   "-net nic,netdev=user.0,model=virtio"
      #   "-netdev user,id=user.0,hostfwd=tcp::2222-:22"
      # ];

      environment.systemPackages = with pkgs; [ jq kubectl docker vault ];

      environment.etc = {
        "kubernetes/test/service1.deployment.yml".source = service1Deployment;
        "kubernetes/test/service2.deployment.yml".source = service2Deployment;
        "kubernetes/test/service1.service.yml".source = service1Service;
        "kubernetes/test/service2.service.yml".source = service2Service;
      };

    };

  };

  testScript = ''
    $master->waitForUnit("docker.service");
    $master->succeed("docker load -i ${service1Image}");
    $master->succeed("docker load -i ${service2Image}");
    $master->waitForUnit("kube-bootstrap.service");
    $master->waitForUnit("rabbitmq-bootstrap.service");
    $master->waitForUnit("vault.service");
    $master->waitForUnit("consul.service");
    # check external service provisionning
    $master->succeed("grep -q foo /etc/hosts");
    # check rabbitmq provisionning
    $master->succeed("su -s ${stdenv.shell} rabbitmq -c 'rabbitmqctl list_users' | grep -q foo");
    $master->succeed("curl -s consul:8500/v1/catalog/services | grep -q foo-queue");
    # check consul provisionning
    $master->succeed("curl -s http://consul:8500/v1/kv/service2 | jq -r '.[].Value' | base64 -d | jq -e '.data == \"foo\"'");
    # check k8s deployment
    $master->succeed("kubectl apply -f /etc/kubernetes/test/");
    $master->waitUntilSucceeds("kubectl get pods -l application=test | wc -l | grep -q 3");
    $master->waitUntilSucceeds("kubectl get services | grep -q service1-pods");
    # check kube2consul
    $master->waitUntilSucceeds("curl -s consul:8500/v1/catalog/services | grep -q service1-pods");
    # check networking
    $master->succeed("kubectl exec \$(kubectl get pod -l service=service1 -o jsonpath='{.items[0].metadata.name}') -- ping -c1 service2-pods.service");
    # check consul-template with vault secrets
    $master->waitUntilSucceeds("kubectl exec \$(kubectl get pod -l service=service2 -o jsonpath='{.items[0].metadata.name}') -- cat /run/consul-template-wrapper/result | grep -q foo");
    $master->waitUntilSucceeds("kubectl exec \$(kubectl get pod -l service=service2 -o jsonpath='{.items[0].metadata.name}') -- cat /run/consul-template-wrapper/result | grep -q plop");
    # check fluentd forwarding
    $master->waitUntilSucceeds("journalctl --unit fluentd --no-pager | grep -q service1");
  '';

in
  makeTest {
    name = "infra";
    nodes = {
      inherit master;
    };
    testScript = testScript;
  }
