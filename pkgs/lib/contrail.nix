{ pkgs, cwPkgs, lib }:

rec {
  buildContrailImageWithPerp = { name, command, preStartScript, fluentd}:
    buildContrailImageWithPerps {
      inherit name;
        services = [
           {name = builtins.replaceStrings ["/"] ["-"] name;
            user = "root";
            inherit command preStartScript fluentd;
           }
        ];
    };

  buildContrailImageWithPerps = { name, services }:
    lib.buildImageWithPerps {
      inherit name services;
      fromImage = lib.images.kubernetesBaseImage;
      extraCommands = ''
        chmod u+w etc
        mkdir -p var/log/contrail etc/contrail
        ln -s /run/consul-template-wrapper/contrail/vnc_api_lib.ini  etc/contrail/vnc_api_lib.ini
      '';
    };

}
