All Cloudwatt Nix Expressions

This package set layout is
```
pkgs
|---- perp
|---- pileus
|---- ... (applications)
|
|---- contrail32Cw
|     |---- api
|     |---- ...
|
|---- debianPackages
|     |---- contrailVrouterAgent
|     |---- ...
|
|     dockerImages
|     |----  hydra
|     |----  contrailApi
|     |----  ...
|
|---- tools
```

### Some Usage Examples

#### Build a Docker image for the `contrail-api-server`

```
% nix-build -A dockerImages.contrailApi
% docker load -i result
```

#### Run the contrail test

```
% nix-build -A contrail32Cw.test.allInOne
% firefox result/log.html
```

#### Interactively run a contrail all-in-one VM

```
% nix-build -A contrail32Cw.test.allInOne.driver
% QEMU_NET_OPTS="hostfwd=tcp::2222-:22" ./result/bin/nixos-run-vms
% ssh -p 2222 root@localhost
```

#### Push an image in a private namespace for testing purposes

First create an account on https://portus.corp.cloudwatt.com/.

Must be done only once:

    % docker login r.cwpriv.net
    % nix-build -A tools.pushImage
    /nix/store/ppl41l4j6v5drdzk80676vvknnv9627b-push-image
    % nix-env -i /nix/store/ppl41l4j6v5drdzk80676vvknnv9627b-push-image

Then you can build any image, and upload it to you personal namespace in the registry:

    % nix-build -A dockerImages.locksmithWorker
    /nix/store/ihnp71p3gxlj9qf41pgs677prjv11q1w-docker-image-worker.tar.gz
    % push-image /nix/store/ihnp71p3gxlj9qf41pgs677prjv11q1w-docker-image-worker.tar.gz jpbraun/locksmith:latest
    Getting image source signatures
    Copying blob sha256:b8d4d3025a405886d28d1978ccbb3b930c465d376353ec4d6aa016991f5eaad3
     85.16 MB / 85.16 MB [=========================================================]
    Copying blob sha256:34418e226e96622b1156e74c904f1e60089d04baa535939e5a36b41bdcfb1002
    [...]

### To test Hydra jobs

Jobs are classic Nix expressions, so to test them, you just have to build them:
```
% nix-build jobset.nix -A dockerImages.contrailApi --arg cloudwatt $PWD
```
Note `pushImages` expressions uses environment variables to provide registry credentials.

To publish a Docker image, [see this doc](doc).

### How external repositories are managed

Expressions from the `nixpkgs` and `nixpkgs-contrail` repositories are
required to build expressions. The file `nixpkgs-fetch.nix` specifies
the commit id that we use by default.
For instance, `nix-build -A contrail.contrailApi` builds the
`contrail-api-server` by using commit id specified in `nixpkgs-fetch.nix`.

You can easily override them:
`% nix-build -A contrail32Cw --arg contrail /path/to/nixpgs-contrail.git --arg nixpkgs /path/to/nixpkgs.git`


### Build a CI
[See CI doc](ci).


### List attributes examples

Root attribute are `contrail`, `ci`, `images`. For instance, to list
all images
```
% nix-env -f default.nix -qaP -A dockerImages
images.contrailApi        docker-image-contrail-api.tar.gz
images.contrailDiscovery  docker-image-contrail-discovery.tar.gz
```
