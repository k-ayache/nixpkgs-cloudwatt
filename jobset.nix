# We define bootstrap_pkgs variable in the jobset definition. This is
# only used to checkout the specified nixpkgs commit.
{ bootstrap_pkgs ? <nixpkgs>
, fetched ? import ./nixpkgs-fetch.nix { nixpkgs = bootstrap_pkgs; }
, nixpkgs ? fetched.pkgs
, contrail ? fetched.contrail
# Should contain the path of the nixpkgs-cloudwatt repository.
# This is used to get the commit id.
, cloudwatt
# Set it to true to push image to the Docker registry
, pushToDockerRegistry ? false
# Set it to true to publish Debian packages to Aptly
, publishToAptly ? false
, unsetProxyForSkopeo ? false
, unsetProxyForAptly ? false
, aptlyUrl ? "http://aptly.int0.aub.cloudwatt.net/api"
}:

let
  pkgs = import nixpkgs {};
  cwPkgs = import ./default.nix { inherit contrail nixpkgs; };
  lib = import ./pkgs/lib { inherit pkgs cwPkgs; };
  getCommitId = pkgs.runCommand "nixpkgs-cloudwatt-commit-id" { buildInputs = [ pkgs.git ]; } ''
    git -C ${cloudwatt} rev-parse HEAD > $out
  '';
  commitId = builtins.replaceStrings ["\n"] [""] (builtins.readFile getCommitId);
  genDockerPushJobs = drvs:
    pkgs.lib.mapAttrs' (n: v: pkgs.lib.nameValuePair (n) (lib.dockerPushImage v commitId unsetProxyForSkopeo)) drvs;
  genDebPublishJobs = drvs:
    pkgs.lib.mapAttrs' (n: v: pkgs.lib.nameValuePair (n) (lib.publishDebianPkg aptlyUrl v unsetProxyForAptly)) drvs;

  # Since lib.buildVrouter is not a derivation, Hydra generates an evaluation error
  contrail32Cw = cwPkgs.contrail32Cw // { lib.buildVrouter = {}; };

in
{
  inherit (cwPkgs) debianPackages dockerImages test;
  inherit contrail32Cw;

  ci = { hydraImage = cwPkgs.ci.hydraImage; }
       // pkgs.lib.optionalAttrs pushToDockerRegistry {
         pushHydraImage = lib.dockerPushImage cwPkgs.ci.hydraImage commitId unsetProxyForSkopeo; };
}

// pkgs.lib.optionalAttrs pushToDockerRegistry {
  pushDockerImages = genDockerPushJobs cwPkgs.dockerImages; }

// pkgs.lib.optionalAttrs publishToAptly {
  publishDebianPackages = genDebPublishJobs cwPkgs.debianPackages; }
