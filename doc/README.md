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