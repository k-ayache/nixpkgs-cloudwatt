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

  contrail32Cw = cwPkgs.contrail32Cw;

  jobs = {
    inherit (cwPkgs) debianPackages dockerImages test;
    inherit contrail32Cw;
  }
  // pkgs.lib.optionalAttrs pushToDockerRegistry {
    pushDockerImages = genDockerPushJobs (
      # exclude sub attrs like dockerImages.pulled
      pkgs.lib.filterAttrs (n: v: pkgs.lib.isDerivation v) cwPkgs.dockerImages
    );
  }
  // pkgs.lib.optionalAttrs publishToAptly {
    publishDebianPackages = genDebPublishJobs cwPkgs.debianPackages; };

  excludedJobs = builtins.map (pkgs.lib.splitString ".") [
    # These are not derivations
    "test.lib"
    "contrail32Cw.lib.buildVrouter"
    # Upload fail because image is to big
    "pushDockerImages.contrailVrouter"
    # FIXME: because of callPackages theses attributes are added to the set
    "dockerImages.pulled.override"
    "dockerImages.pulled.overrideDerivation"
  ];

in
  # We remove excluded jobs
  builtins.foldl' (j: e: pkgs.lib.recursiveUpdate j (pkgs.lib.setAttrByPath e null)) jobs excludedJobs
