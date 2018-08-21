[calico-kube-controllers](https://github.com/projectcalico/kube-controllers) v3.1.3 uses glide for its go dependencies.
dep2nix and go2nix are not able to create a deps.nix file from the glide.lock and glide.yaml file.

The deps.nix file has been generated using a [workaround](https://github.com/kamilchm/go2nix/issues/19#issuecomment-296704557):
glide version 0.13.2-dev

```bash
glide install
rm -rf vendor
cat glide.lock | grep -o "name:.*" | awk '{ pkg = $2; gsub(/\//, "-"); printf("mkdir -p $GOPATH/src/%s && rsync -aP ~/.glide/cache/src/https-%s/ $GOPATH/src/%s/\n", pkg, $2, pkg); }' | xargs -I {} sh -c '{}'
go2nix save
```

The vendor directories of the dependencies must be removed before building.
