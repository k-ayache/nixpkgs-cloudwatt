{ pkgs, python }:

self: super: rec {

  vcversioner = python.mkDerivation {
    name = "vcversioner-2.16.0.0";
    src = pkgs.fetchurl { url = "https://files.pythonhosted.org/packages/c5/cc/33162c0a7b28a4d8c83da07bc2b12cee58c120b4a9e8bba31c41c8d35a16/vcversioner-2.16.0.0.tar.gz"; sha256 = "dae60c17a479781f44a4010701833f1829140b1eeccd258762a74974aa06e19b"; };
    doCheck = false;
  };

  "jsonschema" = python.overrideDerivation super."jsonschema" (old: {
    propagatedBuildInputs = old.propagatedBuildInputs ++ [ vcversioner ];
  });

  "requestsexceptions" = python.overrideDerivation super."requestsexceptions" (old: {
    propagatedBuildInputs = old.propagatedBuildInputs ++ [ super."pbr" ];
  });

}
