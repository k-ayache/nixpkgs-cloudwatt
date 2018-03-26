To update fluentd or add plugins, just modify Gemfile accordingly then run:

    $(nix-build '<nixpkgs>' -A bundix --no-out-link)/bin/bundix --magic
