### Build and Use the Hydra container

First build the Hydra Docker image (from the `nixpkgs-cloudwatt` directory)
```
$ nix-build -A ci.hydra
```

The link `result` points to the image which can be loaded by Docker
```
$ docker load < ./result
```

Hydra needs `PostgreSQL` as database backend. So first run it with Docker
```
$ docker run --name postgres -d postgres:9.3
```

We then have to initialize the database and hydra

```
docker exec postgres su postgres -c "createuser hydra"
docker exec postgres su postgres -c "createdb -O hydra hydra"
```

Note, if you choose different credentials, you have to set the
HYDRA_DBI environment variable as explained below.

```
docker run --link postgres:postgres hydra hydra-init
docker run --link postgres:postgres hydra hydra-create-user admin --role admin --password admin
```

We can then start the Hydra container
```
$ docker run --name hydra -d -p 3000:3000 --link postgres:postgres --volume $PWD/nix-cache:/nix-cache hydra
```

The volume stores a binary cache that is filled by the
`hydra-queue-runner`. Hydra also uses this binary cache to avoid
downloading of packages.

We can then access the webUI. First login, then create a project, a
jobset. Unfortunately, the API is not well documented so we create
them manually.

### Creating a project and a jobset

The script `create-jobset.sh` can be used to create a jobset to build
expressions defined in the current repository.

### Binary cache

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

Note: if you don't provide this environment variable, binary caches
      don't need to be signed (nix.conf `signed-binary-caches` variable is not set).

### Specifying databases credentials

```
docker run -e "HYDRA_DBI=dbi:Pg:dbname=hydra;host=postgres;user=hydra;" hydra
```

If you have to set a password, you have to create a
[`.pgpass`](https://www.postgresql.org/docs/9.3/static/libpq-pgpass.html)
and mount it in the root directory.
```
echo "*:*:*:*:MYPWD" > pgpass
chmod 600 pgpass
docker run -v $PWD/pgpass:/root/.pgpass hydra
```

### Set the number of parallel jobs

The `MAX_JOBS` environment variable define how many jobs can be run in
parallel. By default, it is set to `1`.

```
docker run -e "MAX_JOBS=12" hydra
```

### Stateful datas

There are currently two directories that are stateful

- `/hydra` which contains the build logs and the hydra gcroots (this
  is used to specify elements that must not be garbage collected)
- `/nix-cache` which contains the nix cache. This is currently used
  when the container restart.
