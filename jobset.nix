{ nixpkgs
, registryUrl ? "localhost:5000"
, registryUsername ? ""
  # The path of a file containing the Docker registry password
, registryPasswordFilepath ? "",
}:

let
  pkgs = import nixpkgs {};
  lib = import ./lib pkgs;
  ci = import ./ci {inherit pkgs;};
in
  {
    ci.debug = pkgs.writeText "debug" ''
      echo username:  ${builtins.toString registryUsername}
      echo passwordFilepath: ${builtins.toString registryPasswordFilepath}
      echo url: ${builtins.toString registryUrl}
    '';
    ci.hydraImage = lib.dockerImageBuildProduct ci.hydra;
    ci.pushHydraImage = lib.dockerPushImage {
      image = ci.hydra;
      url = registryUrl; username = registryUsername; passwordFilepath = registryPasswordFilepath;
    };
  }
