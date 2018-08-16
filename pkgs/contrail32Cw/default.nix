{ pkgs, contrailPath, nixpkgsPath, ubuntuKernelHeaders }:

with ubuntuKernelHeaders;

let
  contrailAllPackages = import (contrailPath + "/all-packages.nix") { inherit pkgs; nixpkgs=nixpkgsPath; };

  # Override sources attribute to use the Cloudwatt repositories instead of Contrail repositories
  overrideContrailPkgs = self: super: {
    sources = super.sources32 // (import ./sources.nix { inherit pkgs; });
    contrailVersion = self.contrail32;
    thirdPartyCache = super.thirdPartyCache.overrideAttrs(oldAttrs:
      { outputHash = "1rvj0dkaw4jbgmr5rkdw02s1krw1307220iwmf2j0p0485p7d3h2"; });
  };
  contrailPkgsCw = pkgs.lib.fix (pkgs.lib.extends overrideContrailPkgs contrailAllPackages);

in
  with contrailPkgsCw; {
    inherit api control vrouterAgent
            collector analyticsApi discovery
            queryEngine schemaTransformer svcMonitor
            configUtils vrouterUtils
            vrouterNetns vrouterPortControl
            # webCore
            test
            vms lib
            tools;

  vrouter_ubuntu_3_13_0_83_generic = contrailPkgsCw.lib.buildVrouter ubuntuKernelHeaders_3_13_0_83_generic;
  vrouter_ubuntu_4_4_0_101_generic = contrailPkgsCw.lib.buildVrouter ubuntuKernelHeaders_4_4_0_101_generic;
  vrouter_ubuntu_3_13_0_112_generic = contrailPkgsCw.lib.buildVrouter ubuntuKernelHeaders_3_13_0_112_generic;
  vrouter_ubuntu_3_13_0_125_generic = contrailPkgsCw.lib.buildVrouter ubuntuKernelHeaders_3_13_0_125_generic;
  vrouter_ubuntu_3_13_0_141_generic = contrailPkgsCw.lib.buildVrouter ubuntuKernelHeaders_3_13_0_141_generic;
  vrouter_ubuntu_3_13_0_143_generic = contrailPkgsCw.lib.buildVrouter ubuntuKernelHeaders_3_13_0_143_generic;
  }
