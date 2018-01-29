# Build and load images in docker

    $ nix-build -A tools.loadContrailImages
    [will build images]
    /nix/store/vlcmrnixs5c42fwpz4i9ckwz512fr92i-load-contrail-images
    $ /nix/store/vlcmrnixs5c42fwpz4i9ckwz512fr92i-load-contrail-images/bin/load-contrail-images
    [load images in local docker host]

# Start the infrastructure

Follow instructions at https://git.corp.cloudwatt.com/applications/deployment/tree/master/docker-compose

# Start contrail

    $ make contrail-up

To clean containers run:

    $ make contrail-clean
