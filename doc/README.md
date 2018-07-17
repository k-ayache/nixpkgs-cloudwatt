### How to manually compile a vrouter kernel module

```
$ nix-shell -A contrail32Cw.vrouter_ubuntu_3_13_0_83_generic
[nix-shell] $ unpackPhase
[nix-shell] $ cd contrail-workspace
[nix-shell] $ scons --kernel-dir=$kernelSrc vrouter/vrouter.ko
```

### How to build the vrouter for a new kernel version

First, add fetch expressions in `deps.nix` to get both Ubuntu kernel sources and CONFIG.
```
 ubuntuKernelHeaders_3_13_0_83_generic = ubuntuKernelHeaders "3.13.0-83" [
    (pkgs.fetchurl {
      url = http://fr.archive.ubuntu.com/ubuntu/pool/main/l/linux/linux-headers-3.13.0-83-generic_3.13.0-83.127_amd64.deb;
      sha256 = "f8b5431798c315b7c08be0fb5614c844c38a07c0b6656debc9cc8833400bdd98";
    })
    (pkgs.fetchurl {
      url = http://fr.archive.ubuntu.com/ubuntu/pool/main/l/linux/linux-headers-3.13.0-83_3.13.0-83.127_all.deb;
      sha256 = "7281be1ab2dc3b5627ef8577402fd3e17e0445880d22463e494027f8e904e8fa";
    })
  ];
```

URLs can be found by browsing packages.ubuntu.com. For instance
`https://packages.ubuntu.com/trusty-updates/linux-headers-3.13.0-83-generic`.

Then, add an attribute in `debian-packages.nix` that builds the vrouter
kernel module by using these new sources.
```
contrailVrouterUbuntu_3_13_0_83_generic = contrailVrouterUbuntu deps.ubuntuKernelHeaders_3_13_0_83_generic;
```


### Why we use environment variables to provide credentials to skopeo

We don't want to expose the password value. There is no input type in
Hydra to store and hide a value. Another way could be to store the
password in a file and let Hydra read it. However, Hydra runs Nix in
"restricted mode" which prohibits to access file that are outside of
the nix store.
It would be nice to find another way to do this.


### Debian packages releasing

To publish a Debian package, we have to manually increase the version
defined in `jobset.nix`. We could not use hashes for the version
because we need a ordered version element and we don't want to use the
date in order to let the version number determinist.

### How to test Docker image publish jobs

Currently, the Docker registry url and credential are provided to the
job by using environment variables. We then have to run Nix with these
environment variables (if the Nix deamon is used, you must provide
them to it). If these environment variables are not provided, the
default values points to a local Docker registry. So to locally test
push jobs, you can start a docker registry by using Docker:

```
docker run -d -p 5000:5000 registry

```

Once the docker registry is up and running, we can run the publish job:
```
nix-build jobset.nix -A pushDockerImages.contrailApi --arg cloudwatt $PWD --arg pushToDockerRegistry true
```

We can then explore the registry and pull the image from it.
