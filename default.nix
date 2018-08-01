{ fetched ? import ./nixpkgs-fetch.nix { }
, nixpkgs ? fetched.pkgs
, contrail ? fetched.contrail
}:

let pkgs = import nixpkgs { };
    lib =  import ./pkgs/lib { inherit pkgs cwPkgs; };

    callPackage = pkgs.lib.callPackageWith (
      pkgs // cwPkgs // { inherit pkgs lib callPackage callPackages; });
    callPackages = pkgs.lib.callPackagesWith (
      pkgs // cwPkgs // { inherit pkgs lib callPackage callPackages; });

    cwPkgs = rec {

      perp = callPackage ./pkgs/perp { };

      fluentd = callPackage ./pkgs/fluentd { };

      fluentdCw = callPackage ./pkgs/fluentdCw { };

      vaulttmpfs = callPackage ./pkgs/kubernetes-flexvolume-vault-plugin { };

      consulTemplateMock = callPackage ./pkgs/consul-template-mock { };

      contrail32Cw = import ./pkgs/contrail32Cw {
        inherit pkgs ubuntuKernelHeaders;
        contrailPath = contrail;
        nixpkgsPath = nixpkgs;
      };

      debianPackages = callPackages ./pkgs/debian-packages {
        contrailPkgs = contrail32Cw;
        skydive = skydive.override (_: { enableStatic = true;});
      };

      dockerImages = callPackages ./pkgs/docker-images { contrailPath = contrail; };

      tools = callPackages ./pkgs/tools { };

      locksmith = callPackage ./pkgs/vault-fernet-locksmith { };

      kube2consul = callPackage ./pkgs/kube2consul { };

      calicoKubeControllers = callPackage ./pkgs/calico-kube-controllers { };

      skydive = callPackage ./pkgs/skydive { };

      waitFor = callPackage ./pkgs/wait-for { };

      openstackClient = callPackage ./pkgs/openstackclient { };

      test = callPackages ./test { inherit cwPkgs; contrailPath = contrail; contrailPkgs = contrail32Cw; };

      ubuntuKernelHeaders = callPackages ./pkgs/ubuntu-kernel-headers { };

    };

in cwPkgs
