{ pkgs, cwPkgs, lib }:

let

  yamllintConfig = pkgs.writeText "config" ''
    extends: default
    rules:
      indentation: {spaces: consistent}
  '';

in {

  # Validates yaml file contents
  writeYamlFile = { name, text }: pkgs.writeTextFile {
    inherit name text;
    checkPhase = ''
      ${pkgs.python36Packages.yamllint}/bin/yamllint -c ${yamllintConfig} $n
    '';
  };

  # Render the consul template file and check it is a valid YAML file
  writeConsulTemplateYamlFile =
    { name, text
    # An attribute set to mock Consul data. See
    # https://github.com/nlewo/consul-template-mock for details
    , consulTemplateMocked } :
    let
      mock = pkgs.writeText "mock-${name}.json" (builtins.toJSON consulTemplateMocked);
    in
      pkgs.writeTextFile {
        inherit name text;
        checkPhase = ''
          ${cwPkgs.consulTemplateMock}/bin/consul-template-mock $n ${mock} > text.rendered
          ${pkgs.python36Packages.yamllint}/bin/yamllint text.rendered
        '';
      };
}
