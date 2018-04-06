{ pkgs, cwPkgs, ... }:

with builtins;

rec {

  enableFluentd = any enableFluentdForService;

  enableFluentdForService = pkgs.lib.hasAttrByPath [ "fluentd" "source" "type" ];

  captureServiceStdout = service:
    service ? fluentd && service.fluentd ? source && captureSourceStdout service.fluentd.source;

  captureSourceStdout = source:
    source ? type && source.type == "stdout";

  attrsToFluentd = set:
    concatStringsSep "\n"
      (pkgs.lib.mapAttrsToList (name: value:
        let
          v = if isInt value then toString value
              else if isBool value then (if value == true then "true" else "false")
              else if isString value then value
              else if isAttrs value then attrsToFluentd value
              else if isList value then map attrsToFluentd value
              else abort "attrsToFluentd: value not supported";
          n = if name == "type" then "@type" else name;
          subSection = n: v: "  <${n}>\n${v}\n  </${n}>";
        in
          # support for fluentd 1.x
          if isAttrs value then
            subSection n v
          else if isList value then
            concatStringsSep "\n" (map (subSection n) v)
          else
            "  ${n} ${v}"
      ) set);

  sanitizeFluentdSource = name: source:
    let
      tag = if source ? tag then source.tag else "log.${name}";
    in
      if captureSourceStdout source then
        source // {
          inherit tag;
          type = "named_pipe";
          path = "/tmp/${name}";
          # format is required
          format = if source ? format then source.format else "none";
        }
      else
        source // {
          inherit tag;
        };

  genFluentdSource = { name, fluentd ? {}, ... }@service:
    if enableFluentdForService service then
      ''
        <source>
        ${attrsToFluentd (sanitizeFluentdSource name fluentd.source)}
        </source>
      ''
    else "";

  genFluentdFilter = name: filter:
    let
      start = if filter ? tag then "<filter ${filter.tag}>" else "<filter log.${name}>";
    in
      ''
        ${start}
        ${attrsToFluentd (pkgs.lib.filterAttrs (n: v: n != "tag") filter)}
        </filter>
      '';

  genFluentdFilters = { name, fluentd ? {}, ... }:
    if fluentd ? filters then
      map (genFluentdFilter name) fluentd.filters
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
      newServices ++ [{
        name = "fluentd";
        preStartScript = fluentdPreStart;
        command = "${cwPkgs.fluentdCw}/bin/fluentd --no-supervisor -c ${genFluentdConf services}";
      }];

  # Insert fluentd in image
  # 1. add fluentd package as a parent layer so that it is shared between images
  # 2. add fluentd perp service and configuration
  insertFluentd = imageDesc:
    let
      layer = pkgs.dockerTools.buildImage {
        name = "fluentd";
        fromImage = imageDesc.fromImage;
        contents = [ cwPkgs.fluentdCw ];
      };
    in
      if enableFluentd imageDesc.services then
        imageDesc // { fromImage = layer; services = addFluentdService imageDesc.services; }
      else
        imageDesc;

}
