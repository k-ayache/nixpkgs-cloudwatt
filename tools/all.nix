with builtins;

let pkgsCw = import ../jobset.nix { cloudwatt=./..; pushToDockerRegistry = true; publishToAptly = true; };
    pkgs = (import <nixpkgs> {}).lib;

    # From an attributes set, recursively collect all derivations (such as Hydra)
    # This returns the list of all derivations
    collectDrvs = attrs: let
      drvsList = lib.filter lib.isDerivation (attrValues attrs);
      attrsList = lib.filter (a: ! (lib.isDerivation a) && (isAttrs a)) (attrValues attrs);
    in drvsList ++ (lib.flatten (map collectDrvs attrsList)) ;

in collectDrvs pkgsCw
