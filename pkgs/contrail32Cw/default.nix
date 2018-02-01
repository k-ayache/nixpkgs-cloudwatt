{ pkgs, contrailPath, nixpkgsPath }:

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
    lib.buildVrouter = vrouter;
    inherit api control vrouterAgent
            collector analyticsApi discovery
            queryEngine schemaTransformer svcMonitor
            configUtils vrouterUtils
            vrouterNetns vrouterPortControl
            webCore
            test
            vms
            tools;
  }
