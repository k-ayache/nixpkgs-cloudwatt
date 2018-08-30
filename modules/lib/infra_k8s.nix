{ pkgs }:

with builtins;
with pkgs.lib;

let

  # transform data to hcl format
  # https://www.vaultproject.io/intro/getting-started/policies.html
  generateVaultPolicy = policy:
  concatStringsSep "\n" (mapAttrsToList (path: data: ''path "${path}" {
    ${concatStringsSep ",\n" (mapAttrsToList (key: value: "${key} = ${toJSON value}") data)}
}'') policy);

  generateVaultPolicies = policies:
    mapAttrs (name: policy: generateVaultPolicy policy) policies;

  # generate vault write command from attrs
  writeVaultPath = prefix: path: datas:
    let
      jsonData = pkgs.writeText "${replaceStrings ["/"] ["_"] path}.json" (toJSON datas);
    in
      "cat ${jsonData} | vault write ${prefix}${path} -";

in {

  createVaultPolicies = policies:
    concatStringsSep "\n" (mapAttrsToList (name: policy: ''
      vault policy write ${name} -<<EOF
      ${policy}
      EOF
    '') (generateVaultPolicies policies));

  writeVaultPaths = prefix: paths:
    concatStringsSep "\n" (mapAttrsToList (writeVaultPath prefix) paths);

}
