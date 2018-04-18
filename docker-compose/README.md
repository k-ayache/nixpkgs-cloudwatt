# Usage

## Build and load images in docker

    $ nix-build -A tools.loadContrailImages
    [will build images]
    /nix/store/vlcmrnixs5c42fwpz4i9ckwz512fr92i-load-contrail-images
    $ /nix/store/vlcmrnixs5c42fwpz4i9ckwz512fr92i-load-contrail-images/bin/load-contrail-images
    [load images in local docker host]

## Start the infrastructure

Follow instructions at https://git.corp.cloudwatt.com/applications/deployment/tree/master/docker-compose
Start:

    $ make vault-init
    $ source .docker-compose/vault.env
    $ make infrastructure-up
    $ make openstack-up

## Start keystone

Clone https://git.corp.cloudwatt.com/docker/keystone-all to start keystone:

    $ source `.docker-compose/vault.env` from the infrastructure directory
    $ docker pull r.cwpriv.net/keystone/all:9.0.0-682774535ef9e4fa
    $ docker tag r.cwpriv.net/keystone/all:9.0.0-682774535ef9e4fa r.cwpriv.net/keystone/all:9.0.0-1
    $ make dev-up

## Create endpoinds:

In applications/deployment/docker-compose create endpoints:

    $ source `.docker-compose/vault.env` from the infrastructure directory
    $ make openstack-catalog

## Create keystone user

In docker/keystone-all create keystone user:

    $ source `.docker-compose/vault.env` from the infrastructure directory
    $ make dev-service-user

## Start contrail

In nixpkgs-cloudwatt/docker-compose:

    $ source `.docker-compose/vault.env` from the infrastructure directory
    $ make dev-vault-data
    $ make contrail-service-user
    $ make contrail-up

# Development

Vault passwords for contrail are stored in `vault-data.yml` file. The secrets
are provisionned in vault as as dependency to the contrail-up target.

Same for consul data which is in `consul-data/consul-config_opencontrail_data.json`.
This means the JSON will be stored in the consul path `config/opencontrail/data`.

The images build and configuration can be found in the `../pkgs/docker-images/`
directory.

After deployment, do the provisioning and test ping between the 2 compute nodes:

    $ make contrail-provision
    $ make contrail-test

If you get ping succes your contrail build works mainly fine

When you stop the deployment, you have to clean the containers before starting it again, run:

    $ make contrail-clean

