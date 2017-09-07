{ nixpkgs
, registryUrl ? "localhost:5000"
, registryUsername ? null
  # The path of a file containing the Docker registry password
, registryPasswordFilepath ? null,
}:

let
  pkgs = import nixpkgs {};
  lib = import ./lib pkgs;
  ci = import ./ci {inherit pkgs;};
  # Read the registry password from a local file
  registryPassword = if (registryPasswordFilepath != null && builtins.pathExists registryPasswordFilepath)
                     then pkgs.lib.removeSuffix "\n" (builtins.readFile registryPasswordFilepath)
		     else null;
in
  {
    ci.hydraImage = lib.dockerImageBuildProduct ci.hydra;
    ci.pushHydraImage = lib.dockerPushImage {
      image = ci.hydra;
      url = registryUrl; username = registryUsername; password = registryPassword;
    };
  }
