{ pkgs }:

rec {

  locksmithConf = pkgs.writeTextFile {
    name = "config.yaml.ctmpl";
    text = ''
      {{ $locksmith := keyOrDefault "/config/locksmith/data" "{}" | parseJSON -}}
      {{ $primaryVault := ( "{}" | parseJSON ) | or (index $locksmith "primary-vault") -}}
      {{ $secondaryVault := ( "{}" | parseJSON ) | or (index $locksmith "secondary-vault") -}}
      primary-vault:
        address: {{ "https://vault.service:8200" | or (index $primaryVault "address") }}
        proxy: {{ "http://http-proxy.localdomain:8123" | or (index $primaryVault "proxy") }}
        token-file: {{ "/run/vault-token/vault-token" | or (index $primaryVault "token-file") }}
        token-renew: {{ "true" | or (index $primaryVault "token-renew") }}

      secondary-vaults:
        - address: {{ index $secondaryVault "address" }}
          proxy: {{ index $secondaryVault "proxy" }}
          {{ with secret "secret/locksmith" }}token: {{  .Data.secondaryVault.token }}{{ end }}
          token-renew: {{ "true" | or (index $secondaryVault "token-renew") }}

      ttl: {{ "120" | or (index $locksmith "ttl") }}

      secret-path: {{ "secret/fernet-keys" | or (index $locksmith "secretPath") }}

      health: {{ "true" | or (index $locksmith "health") }}

      lock: {{ "true" | or (index $locksmith "lock") }}

      lock-key: {{ "locks/locksmith/.lock" | or (index $locksmith "lockKey") }}

      consul-address: {{ "http://consul.localdomain:8500" | or (index $locksmith "consul-address") }}

      {{ with secret "secret/locksmith" -}}
      consul-token: {{ .Data.consulToken }}
      {{- end }}
    '';
  };

  locksmithPreStart = ''
    consul-template-wrapper -- -once \
      -template "${locksmithConf}:/run/consul-template-wrapper/etc/locksmith/config.yaml"
  '';
}
