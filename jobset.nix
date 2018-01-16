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
}:

let
  pkgs = import nixpkgs {};
  lib = import ./pkgs/lib pkgs;
  default = import ./default.nix { inherit contrail nixpkgs; };
  getCommitId = pkgs.runCommand "nixpkgs-cloudwatt-commit-id" { buildInputs = [ pkgs.git ]; } ''
    git -C ${cloudwatt} rev-parse HEAD > $out
  '';
  commitId = builtins.replaceStrings ["\n"] [""] (builtins.readFile getCommitId);
  genDockerPushJobs = drvs:
    pkgs.lib.mapAttrs' (n: v: pkgs.lib.nameValuePair (n) (lib.dockerPushImage v commitId)) drvs;
  genDebPublishJobs = drvs:
    pkgs.lib.mapAttrs' (n: v: pkgs.lib.nameValuePair (n) (lib.publishDebianPkg v)) drvs;
in
{
  ci = { hydraImage = lib.dockerImageBuildProduct default.ci.hydraImage; }
       // pkgs.lib.optionalAttrs pushToDockerRegistry
          { pushHydraImage = lib.dockerPushImage default.ci.hydraImage commitId; };
  contrail32Cw = default.contrail32Cw;
  debianPackages = pkgs.lib.mapAttrs (n: v: lib.debianPackageBuildProduct v) default.debianPackages;
  dockerImages = pkgs.lib.mapAttrs (n: v: lib.dockerImageBuildProduct v) default.dockerImages;
} // pkgs.lib.optionalAttrs pushToDockerRegistry {
       pushDockerImages = genDockerPushJobs default.images; }
  // pkgs.lib.optionalAttrs publishToAptly {
       publishDebianPackages = genDebPublishJobs default.debianPackages; }
