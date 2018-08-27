{ lib, pkgs, kube2consul }:

let
  tokenTemplate = pkgs.writeTextFile {
    name = "consul_token.ctmpl";
    text = ''
      {{ with secret "secret/kube2consul" }}{{ .Data.consul_token }}{{ end }}
    '';
  };
in

lib.buildImageWithPerp {
    name = "kube2consul/worker";
    fromImage = lib.images.kubernetesBaseImage;
    command = "${kube2consul}/bin/kube2consul -lock -consul-token=`cat /run/consul-template-wrapper/kube2consul/consul_token`";
    preStartScript = ''
      export K2C_CONSUL_API=''${K2C_CONSUL_API:-consul.localdomain:8500}
      export K2C_V=''${K2C_V:-1}

      consul-template-wrapper -- -once \
        -template="${tokenTemplate}:/run/consul-template-wrapper/kube2consul/consul_token"
    '';
}
