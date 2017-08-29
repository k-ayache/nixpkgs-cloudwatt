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
$ docker run --name hydra -d -p 3000:3000 --link postgres:postgres hydra
```

We can then access the webUI. First login, then create a project, a
jobset. Unfortunately, the API is not well documented so we create
them manually.

### Project example

```
Display name: 	Contrail CI
Description: 	Contrail Build
Homepage: 	(not specified)
Owner: 	admin
Enabled: 	Yes
```

### Jobset example
Then you can create a jobset in this project.

```
State:  Enabled
Description:    Contrail
Nix expression:         jobset.nix in input ciSrc
Check interval:         60
Scheduling shares:      100 (100.00% out of 100 shares)
Enable email notification:      No
Email override:         
Number of evaluations to keep:  5

Inputs
Input name      Type            Values
ciSrc           Git checkout    https://github.com/nlewo/nixpkgs-contrail
nixpkgs         Git checkout    https://github.com/NixOS/nixpkgs-channels nixpkgs-unstable
```

### Signing the binary cache

The container can take the environment variable `BINARY_CACHE_SECRET`
that should contain the secret used to sign the binary cache.

To generate this secret:
```
nix-store --generate-binary-cache-key hydra hydra.secret hydra.public
```

Then, run the container with
```
docker run -e "BINARY_CACHE_SECRET=$(cat hydra.secret)" hydra
```

### Specifying databases credentials

```
docker run -e "HYDRA_DBI=dbi:Pg:dbname=hydra;host=postgres;user=hydra;" hydra
```
