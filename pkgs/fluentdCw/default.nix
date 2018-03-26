{ writeShellScriptBin, fluentd }:

let
  plugins = ./plugins;
in
  writeShellScriptBin "fluentd" ''
    ${fluentd}/bin/fluentd -p ${plugins} $@
  ''
