# Usage

## Build and load images in docker

    $ nix-build -A tools.loadContrailImages
    [will build images]
    /nix/store/vlcmrnixs5c42fwpz4i9ckwz512fr92i-load-contrail-images
    $ /nix/store/vlcmrnixs5c42fwpz4i9ckwz512fr92i-load-contrail-images/bin/load-contrail-images
    [load images in local docker host]

## Start the infrastructure

Follow instructions at https://git.corp.cloudwatt.com/applications/deployment/tree/master/docker-compose

## Start contrail

    $ make contrail-up

When you stop the deployment, you have to clean the containers before starting it again, run:

    $ make contrail-clean

# Development

Vault passwords for contrail are stored in `vault-data.yml` file. The secrets
are provisionned in vault as as dependency to the contrail-up target.

Same for consul data which is in `consul-data/consul-config_opencontrail_data.json`.
This means the JSON will be stored in the consul path `config/opencontrail/data`.

The images build and configuration can be found in the `../pkgs/docker-images/`
directory.
