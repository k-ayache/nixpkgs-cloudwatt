{ writeShellScriptBin, fluentd }:

let
  plugins = ./plugins;
in
  writeShellScriptBin "fluentd" ''
    exec ${fluentd}/bin/fluentd -p ${plugins} $@
  ''
