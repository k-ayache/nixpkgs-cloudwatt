{ nixpkgs, declInput }:
let
  pkgs = import nixpkgs {};
  desc = {
    trunk = {
      description = "Build master of nixpkgs-cloudwatt";
      checkinterval = "60";
      enabled = "1";
      nixexprinput = "cloudwatt";
      nixexprpath = "jobset.nix";
      schedulingshares = 100;
      enableemail = false;
      emailoverride = "";
      keepnr = 3;
      hidden = false;
      inputs = {
        cloudwatt = {
          value = "https://git.corp.cloudwatt.com/applications/nixpkgs-cloudwatt master keepDotGit";
          type = "git";
          emailresponsible = false;
        };
        bootstrap_pkgs = {
          value = "https://git.corp.cloudwatt.com/applications/nixpkgs acd89daabcb47cb882bc72ffc2d01281ed1fecb8";
          type = "git";
          emailresponsible = false;
        };
        pushToDockerRegistry = {
          value = "true";
          type = "boolean";
          emailresponsible = false;
        };
        publishToAptly = {
          value = "true";
          type = "boolean";
          emailresponsible = false;
        };
      };
    };
    staging = {
      description = "Build master of nixpkgs-cloudwatt and nixpkgs-contrail";
      checkinterval = "60";
      enabled = "1";
      nixexprinput = "cloudwatt";
      nixexprpath = "jobset.nix";
      schedulingshares = 100;
      enableemail = false;
      emailoverride = "";
      keepnr = 1;
      hidden = false;
      inputs = {
        cloudwatt = {
          value = "https://git.corp.cloudwatt.com/applications/nixpkgs-cloudwatt master keepDotGit";
          type = "git";
          emailresponsible = false;
        };
        bootstrap_pkgs = {
          value = "https://git.corp.cloudwatt.com/applications/nixpkgs acd89daabcb47cb882bc72ffc2d01281ed1fecb8";
          type = "git";
          emailresponsible = false;
        };
        contrail = {
          value = "https://github.com/nlewo/nixpkgs-contrail master";
          type = "git";
          emailresponsible = false;
        };
      };
    };
  };

in {
  jobsets = pkgs.runCommand "spec.json" {} ''
    cat <<EOF
    ${builtins.toXML declInput}
    EOF
    cat >$out <<EOF
    ${builtins.toJSON desc} 
    EOF
  '';
}
