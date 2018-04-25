## To add a new jobset

We have to modify the file `jobsets-declarative.nix` to add a jobset
on the integration CI or to modify `jobsets-declarative-sec.nix` for
the secure CI.

The CI pulls this file to create the jobsets every minute.

Note the json job file can be locally built and validated
`nix-build ci/jobsets-declarative-sec.nix  --arg nixpkgs '<nixpkgs>' --arg declInput '{}' -Q | xargs cat | jq`


## Build and Use the Hydra container

First build the Hydra Docker image (from the `nixpkgs-cloudwatt` directory)
```
$ nix-build -A ci.hydraImage
```

The link `result` points to the image which can be loaded by Docker
```
$ docker load < ./result
```

The test [Hydra](../tests/hydra.nix) spawns a postgresql container and
this Hydra container.

The attribute `test.hydra.driverDockerCompose` produces a script that
runs a Docker compose stack with Postgresql and Hydra.

We can access the webUI at `http://localhost:3000` with the user
`admin` and password `admin`.

### Container environment variables

#### `HYDRA_DBI` and `POSTGRES_PASSWORD`

`HYDRA_DBI` is the postgresql connection scheme. Default to
`dbi:Pg:dbname=hydra;host=postgres;user=hydra;`.

`POSTGRES_PASSWORD` is the password of the database owner.


#### `BINARY_CACHE_KEY_SECRET` and `BINARY_CACHE_KEY_PUBLIC`

The container can take the environment variable `BINARY_CACHE_KEY_SECRET`
that should contain the secret used to sign the binary cache.

To generate this secret:
```
nix-store --generate-binary-cache-key hydra hydra.secret hydra.public
```

Then, run the container with
```
docker run -e "BINARY_CACHE_KEY_SECRET=$(cat hydra.secret)" hydra
```

If we want to use this generated signed binary cache to speed up first Hydra
evaluation, you have to provide the environment variable
`BINARY_CACHE_KEY_SECRET`.

Note: if you don't provide this environment variable, used binary caches
      don't need to be signed (nix.conf `signed-binary-caches` variable is not set).


### `MAX_JOBS`

The `MAX_JOBS` environment variable define how many jobs can be run in
parallel. By default, it is set to `1`.

```
docker run -e "MAX_JOBS=12" hydra
```


### `HYDRA_ADMIN_USERNAME` and `HYDRA_ADMIN_PASSWORD`

If environment variables `HYDRA_ADMIN_USERNAME` and `HYDRA_ADMIN_PASSWORD`
are both set, they are then used to create an account with the `admin` role.


### `DECL_PROJECT_NAME` `DECL_FILE` `DECL_TYPE` `DECL_VALUE`

If these variables are set, a declarative project is created a
container startup time.

    - `DECL_PROJECT_NAME` is the name of the project (default to "cloudwatt")
    - `DECL_TYPE` is the type of the input (default to "git")
    - `DECL_VALUE` is the url of the repository that contains the declarative project specification file
    - `DECL_FILE` is the name declarative project specification file


### Volumes or Stateful datas

There are currently two directories that are stateful

- `/hydra` which contains the build logs and the hydra gcroots (this
  is used to specify elements that must not be garbage collected)
- `/nix-cache` which contains the nix cache. This is currently used
  when the container restart.


## How project and jobsets are created

We are using the Hydra declarative project feature that allows Hydra
to create project and jobsets from description files provided in this
repository.

Basically, a declarative project contains a static Hydra jobset named
`.jobsets`. This project and jobset are created at container start
time and are configured with environment variables `DECL_*` (see
above). The file `spec.json` is used to configure the jobset
`.jobset`. This jobset contains a job that creates other jobsets of
the project by evaluating the `jobsets-declarative.nix`.

To create jobsets on the sec CI, edit files `spec-sec.json` and
`jobsets-declarative-sec.nix`.

Resources:

- https://github.com/shlevy/declarative-hydra-example
- https://github.com/NixOS/hydra/blob/master/doc/manual/declarative-projects.xml
