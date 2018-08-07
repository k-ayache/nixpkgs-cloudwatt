{ pkgs, lib }:

lib.writeConsulTemplateYamlFile {
  name = "config.yaml.ctmpl";
  text = ''
    ---
    {{$locksmith := keyOrDefault "/config/locksmith/data" "{}" | parseJSON -}}
    {{- $primaryVault := index $locksmith "primary-vault" -}}
    {{- $secondaryVaults := index $locksmith "secondary-vaults" -}}
    {{- if $primaryVault -}}
    primary-vault:
      {{- if index $primaryVault "address"}}
      address: {{index $primaryVault "address"}}
      {{- end}}
      {{- if index $primaryVault "proxy"}}
      proxy: {{index $primaryVault "proxy"}}
      {{- end}}
      token-file: {{or (index $primaryVault "token-file") "/run/vault-token/vault-token"}}
      token-renew: {{or (index $primaryVault "token-renew") "true"}}

    {{end -}}
    {{- if $secondaryVaults -}}
    secondary-vaults:
      {{- range $i, $v := $secondaryVaults}}
      - address: {{index $v "address"}}
        {{- if index $v "proxy"}}
        proxy: {{index $v "proxy"}}
        {{- end}}
        {{- with secret "secret/locksmith"}}
        token: {{index .Data.secondaryVaultsTokens $i}}
        {{- end}}
        token-renew: {{or (index $v "token-renew") "true"}}
      {{- end}}

    {{end -}}
    ttl: {{or (index $locksmith "ttl") "120"}}

    secret-path: {{or (index $locksmith "secretPath") "secret/fernet-keys"}}

    health: {{or (index $locksmith "health") "true"}}

    lock: {{or (index $locksmith "lock") "true"}}

    lock-key: {{or (index $locksmith "lockKey") "locks/locksmith/.lock"}}

    {{- if index $locksmith "consul-address"}}
    consul-address: {{index $locksmith "consul-address"}}
    {{- end}}

    {{with secret "secret/locksmith" -}}
    consul-token: {{.Data.consulToken}}
    {{- end}}
  '';
  consulTemplateMocked = {
    secret = {
      "secret/locksmith" = {
        "consulToken" = "secret-consul-token";
        "secondaryVaultsTokens" = [ "secret-secondaryVaults[0]-token" ];};};
    key = {
      "/config/locksmith/data" = ''
        {
          "primary-vault": {
            "address": "https://vault1.service:8200"
          },
          "secondary-vaults": [
            {
              "address": "https://vault2.service:8200"
            }
          ]
        }'';};
  };
}
