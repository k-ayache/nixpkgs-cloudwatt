In this repository are defined

- Contrail builds and tests (coming from `https://github.com/nlewo/nixpkgs-contrail`)
- Docker image builds
- Debian package builds
- Build of the Hydra CI image
- Hydra jobs


### Some Usage Examples

Build a Docker image for the `contrail-api-server`
```
% nix-build -A images.contrailApi
% docker load -i result
```

To run the contrail test
```
% nix-build -A contrail.test.contrail
% firefox result/log.html
```

To interactively run a contrail all-in-one VM
```
% nix-build -A contrail.test.contrail.driver
% QEMU_NET_OPTS="hostfwd=tcp::2222-:22" ./result/bin/nixos-run-vms
% ssh -p 2222 root@localhost
```


### To test Hydra jobs

Jobs are classic Nix expressions, so to test them, you just have to build them:
```
% nix-build jobset.nix -A pushImages.contrailApi
```
Note `pushImages` expressions uses environment variables to provide registry credentials.


### How external repositories are managed

Expressions from the `nixpkgs` and `nixpkgs-contrail` repositories are
required to build expressions. The file `nixpkgs-fetch.nix` specifies
the commit id that we use by default.
For instance, `nix-build -A contrail.contrailApi` builds the
`contrail-api-server` by using commit id specified in `nixpkgs-fetch.nix`.

You can easily override them:
`% nix-build -A contrail.contrailApi --arg contrail /path/to/nixpgs-contrail.git --arg nixpkgs /path/to/nixpkgs.git`


### Build a CI
[See CI doc](ci).


### List attributes examples

Root attribute are `contrail`, `ci`, `images`. For instance, to list
all images
```
% nix-env -f default.nix -qaP -A images
images.contrailApi        docker-image-contrail-api.tar.gz
images.contrailDiscovery  docker-image-contrail-discovery.tar.gz
```
