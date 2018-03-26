{ pkgs, cwPkgs }:

let

  enableFluentdForService = service: service ? fluentd && service.fluentd ? source && service.fluentd.source ? type;

  captureServiceStdout = service:
    service ? fluentd && service.fluentd ? source && captureSourceStdout service.fluentd.source;

  captureSourceStdout = source:
    source ? type && source.type == "stdout";

  attrsToFluentd = s:
    builtins.concatStringsSep "\n"
      (pkgs.lib.mapAttrsToList (name: value:
        # support for fluentd 1.x
        if builtins.isAttrs value then
          ''
            <${name}>
            ${attrsToFluentd value}
            </${name}>
          ''
        else
          "  ${if name == "type" then "@type" else name} ${value}"
      ) s);

  sanitizeFluentdSource = name: source:
    if captureSourceStdout source then
      source // {
        type = "named_pipe";
        path = "/tmp/${name}";
        # format is required
        format = if source ? format then source.format else "none";
      }
    else
      source;

  genFluentdSource = { name, fluentd ? {}, ... }@service:
    if enableFluentdForService service then
      ''
        <source>
        ${attrsToFluentd (sanitizeFluentdSource name fluentd.source)}
          tag log.${name}
        </source>
      ''
    else "";

  genFluentdFilters = { fluentd ? {}, ... }:
    if fluentd ? filters then
      "${fluentd.filters}\n"
    else
      "";

  genFluentdConf = services: pkgs.writeTextFile {
    name = "fluentd.conf";
    text = ''
      # used to check that fluentd is initialized
      <source>
        @type forward
        port 24225
      </source>
      ${pkgs.lib.concatStrings (map genFluentdSource services)}
      <filter>
        @type generic_metadata
      </filter>
      ${pkgs.lib.concatStrings (map genFluentdFilters services)}
      <match log.**>
        @type forward
        time_as_integer true
        <server>
          name local
          host fluentd.localdomain
        </server>
      </match>
    '';
  };

  addFluentdService = services:
    let
      enableFluentd = builtins.any enableFluentdForService services;
      newServiceCommand = s:
        if captureServiceStdout s then
          "rundeux ${s.command} :: ${pkgs.coreutils}/bin/tee /tmp/${s.name}"
        else
          s.command;
      newService = s:
        if enableFluentdForService s then
          s // {
            preStartScript = ''
              ${s.preStartScript}
              ${cwPkgs.waitFor}/bin/wait-for 127.0.0.1:24225 -t 30 -q
            '';
            command = newServiceCommand s;
          }
        else
          s;
      newServices = map newService services;
      fluentdPreStart = pkgs.lib.concatStrings (map ({ name, fluentd ? {}, ... }@service:
        if captureServiceStdout service then
          "[ ! -p /tmp/${name} ] && mkfifo /tmp/${name}\n"
        else
          ""
      ) services);
    in
      if enableFluentd then
        newServices ++ [{
          name = "fluentd";
          preStartScript = fluentdPreStart;
          command = "${cwPkgs.fluentdCw}/bin/fluentd --no-supervisor -c ${genFluentdConf services}";
        }]
      else
        services;

in rec {
  # We use environment variables REGISTRY_URL, REGISTRY_USERNAME,
  # REGISTRY_PASSWORD to specify the url and credentials of the
  # registry.
  # The commit ID is used to generate the image tag.
  dockerPushImage = image: commitId: unsetProxy:
    let
      imageRef = "${image.imageName}:${commitId}-${builtins.baseNameOf image.out}";
      jobName = with pkgs.lib; "push-" + (removeSuffix ".tar" (removeSuffix ".gz" image.name));
      outputString = "Pushed image ${image.imageName} with content ${builtins.baseNameOf image.out}  ";
    in
      pkgs.runCommand jobName {
        buildInputs = with pkgs; [ jq skopeo ];
        impureEnvVars = pkgs.lib.optionals (!unsetProxy) pkgs.stdenv.lib.fetchers.proxyImpureEnvVars ++
          [ "REGISTRY_URL" "REGISTRY_USERNAME" "REGISTRY_PASSWORD" ];
        outputHashMode = "flat";
        outputHashAlgo = "sha256";
        outputHash = builtins.hashString "sha256" outputString;
      } ''
      DESTCREDS=""
      CREDS=""
      if [ ! -z $REGISTRY_USERNAME ] && [ ! -z $REGISTRY_USERNAME ]; then
        DESTCREDS="--dest-creds $REGISTRY_USERNAME:$REGISTRY_PASSWORD"
        CREDS="--creds $REGISTRY_USERNAME:$REGISTRY_PASSWORD"
      fi
      if [ -z $REGISTRY_URL ]; then
        REGISTRY_URL="localhost:5000"
      fi

      echo "Ungunzip image (since skopeo doesn't support tgz image)..."
      gzip -d ${image.out} -c > image.tar
      echo "Pushing unzipped image ${image.out} ($(du -hs image.tar | cut -f1)) to registry $REGISTRY_URL/${imageRef} ..."
      skopeo --insecure-policy copy $DESTCREDS --dest-tls-verify=false --dest-cert-dir=/tmp docker-archive:image.tar docker://$REGISTRY_URL/${imageRef}
      skopeo --insecure-policy inspect $CREDS --tls-verify=false --cert-dir=/tmp docker://$REGISTRY_URL/${imageRef}
      echo -n "${outputString}" > $out
    '';

  oneShot = cmd: ''
    ${pkgs.bash}/bin/bash -c "${cmd}; perpctl X $SVNAME"
  '';

  genPerpRcMain = {
    name,
    command,
    preStartScript ? "",
    chdir ? "",
    oneshot ? false,
    ...
  }: pkgs.writeTextFile {
    name = "${name}-rc.main";
    executable = true;
    destination = "/etc/perp/${name}/rc.main";
    text = ''
      #!${pkgs.bash}/bin/bash

      exec 2>&1

      TARGET=$1
      SVNAME=$2

      ${preStartScript}

      OPTIONS=""
      ${if chdir != "" then ''OPTIONS="$OPTIONS -c ${chdir}"'' else ""}

      start() {
        exec runtool $OPTIONS ${if oneshot then oneShot command else command}
      }

      reset() {
        exit 0
      }

      eval $TARGET "$@"
    '';
  };

  # Build an image where 'command' is started by Perp
  buildImageWithPerp = {
    name,
    fromImage,
    command,
    preStartScript ? "",
    contents ? [],
    extraCommands ? "",
    fluentd ? {},
  }:
    buildImageWithPerps {
      inherit name fromImage contents extraCommands;
      services = [
        {
          inherit preStartScript command fluentd;
          name = builtins.replaceStrings ["/"] ["-"] name;
        }
      ];
    };

  buildImageWithPerps = { name, fromImage ? null, services, contents ? [], extraCommands ? "" }:
    pkgs.dockerTools.buildImage {
      inherit name fromImage;
      config = {
        Cmd = [ "/usr/sbin/perpd" ];
      };
      contents = map genPerpRcMain (addFluentdService services) ++ contents;
      extraCommands = ''
        ${pkgs.findutils}/bin/find etc/perp -type d -exec chmod +t {} \;
      '' + extraCommands;
    };

  # This helper takes a Docker Compose file to generate a script that
  # loads Docker images used by this stack and run docker compose.  Be
  # careful, to provide the image, you have to use the basename of the
  # output path. For instance:
  #    ...
  #    container = {
  #      image = builtins.baseNameOf myImage;
  #    ...
  runDockerComposeStack = stack:
    let
      dockerComposeFile = pkgs.writeTextFile {
        name = "docker-compose.yaml";
        text = pkgs.lib.generators.toYAML {} stack;
      };
    in
      pkgs.writeScript "run-docker-compose-stack" ''
        images=$(cat ${pkgs.writeReferencesToFile dockerComposeFile} | grep -v ${dockerComposeFile})
        for i in $images; do
          echo "docker load -i $i ..."
          imageRef=$(${pkgs.docker}/bin/docker load -i $i | grep "Loaded image" | sed 's/Loaded image: \(.*\)/\1/')
          echo "docker tag $imageRef $(basename $i)"
          ${pkgs.docker}/bin/docker tag $imageRef $(basename $i)
        done
        echo "docker-compose -f ${dockerComposeFile} up -d ..."
        ${pkgs.docker_compose}/bin/docker-compose -f ${dockerComposeFile} up -d
        echo
        echo "To get container logs:"
        echo "  ${pkgs.docker_compose}/bin/docker-compose -f ${dockerComposeFile} logs -f"
        echo "To destroy the stack:"
        echo "  ${pkgs.docker_compose}/bin/docker-compose -f ${dockerComposeFile} down"
      '';
}
