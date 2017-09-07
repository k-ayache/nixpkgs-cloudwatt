### Why we use environment variables to provide credentials to skopeo

We don't want to expose the password value. There is no input type in
Hydra to store and hide a value. Another way could be to store the
password in a file and let Hydra read it. However, Hydra runs Nix in
"restricted mode" which prohibits to access file that are outside of
the nix store.
It would be nice to find another way to do this.