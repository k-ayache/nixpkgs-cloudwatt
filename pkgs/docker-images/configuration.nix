pkgs:

let

  contrailServices = {
    api = {
      name = "api";
      dns = "opencontrail-api.service";
      port = "8082";
    };
    ifmap = {
      name = "ifmap";
      dns = "opencontrail-ifmap.service";
      port = "8443";
    };
    discovery = {
      name = "discovery";
      dns = "opencontrail-discovery.service";
      port = "5998";
    };
    schemaTransformer = {
      name = "schema_transformer";
    };
    svcMonitor = {
      name = "svc_monitor";
    };
    control = {
      name = "control";
    };
    collector = {
      name = "collector";
      dns = "opencontrail-collector.service";
      port = "8086";
    };
    analyticsApi = {
      name = "analytics_api";
    };
    redis = {
      name = "redis";
      dns = "opencontrail-redis.service";
      port = "6379";
    };
  };

  contrailConfig = conf: ''
    {{ $opencontrail := keyOrDefault "/config/opencontrail/data" "{}" | parseJSON -}}
  '' + conf;

  contrailLogConfig = service: ''
    {{- if $opencontrail.${service.name}.log_level }}
    log_level = {{ $opencontrail.${service.name}.log_level }}
    {{- else if $opencontrail.log_level }}
    log_level = {{ $opencontrail.log_level }}
    {{- else }}
    log_level = SYS_INFO
    {{- end }}
    log_local = 1
  '';

  contrailCassandraConfig = ''
    cassandra_server_list = {{ range $data := service "opencontrail-config-cassandra" }}{{$data.Address}} {{ end }}
  '';

  contrailCassandraAnalyticsConfig = ''
    cassandra_server_list = {{ range $data := service "opencontrail-analytics-cassandra" }}{{$data.Address}}:9042 {{ end }}
  '';

  contrailRabbitConfig = ''
    rabbit_server = {{- range $index, $data := service "opencontrail-queue" }}
      {{- if $index}},{{end}}{{$data.Address}}
    {{- end }}
    rabbit_port = 5672
    rabbit_user = opencontrail
    rabbit_password = {{ with secret "secret/opencontrail" -}}{{ .Data.queue_password }}{{- end }}
    rabbit_vhost = opencontrail
  '';

  contrailZookeeperConfig = ''
    zk_server_port = 2181
    zk_server_ip = {{- range $index, $data := service "opencontrail-config-zookeeper" }}{{if $index}},{{end}}{{$data.Address}}{{- end }}
  '';

  containerIP = ''{{- file "/my-ip" -}}'';

in {

  contrailDiscovery = pkgs.writeTextFile {
    name = "contrail-discovery.conf.ctmpl";
    text = contrailConfig ''
      [DEFAULTS]
      listen_ip_addr = ${containerIP}
      listen_port = ${contrailServices.discovery.port}

      # minimim time to allow client to cache service information (seconds)
      ttl_min = 300
      # maximum time to allow client to cache service information (seconds)
      ttl_max = 1800
      # health check ping interval <=0 for disabling
      hc_interval = 5
      # maximum hearbeats to miss before server will declare publisher out of service.
      hc_max_miss = 3
      # use short TTL for agressive rescheduling if all services are not up
      ttl_short = 1

      ${contrailLogConfig contrailServices.discovery}
      ${contrailCassandraConfig}

      [DNS-SERVER]
      policy=fixed
    '';
  };

  contrailApi = pkgs.writeTextFile {
    name = "contrail-api.conf.ctmpl";
    text = contrailConfig ''
      [DEFAULTS]
      listen_ip_addr = ${containerIP}
      # FIXME, the code is publishing ifmap_server_ip instead of listen_ip_addr to the discovery
      ifmap_server_ip = ${containerIP}
      listen_port = ${contrailServices.api.port}

      disc_server_ip = ${contrailServices.discovery.dns}
      disc_server_port = ${contrailServices.discovery.port}

      ${contrailLogConfig contrailServices.api}
      ${contrailCassandraConfig}
      ${contrailRabbitConfig}
      ${contrailZookeeperConfig}

      [IFMAP_SERVER]
      ifmap_listen_ip = ${containerIP}
      ifmap_listen_port = ${contrailServices.ifmap.port}
      {{ with secret "secret/opencontrail" -}}
      ifmap_credentials = ifmap:{{ .Data.ifmap_password}}
      {{- end }}
    '';
  };

  contrailSchemaTransformer = pkgs.writeTextFile {
    name = "contrail-schema.conf.ctmpl";
    text = contrailConfig ''
      [DEFAULTS]
      api_server_ip = ${contrailServices.api.dns}
      disc_server_ip = ${contrailServices.discovery.dns}
      disc_server_port = ${contrailServices.discovery.port}

      ${contrailLogConfig contrailServices.schemaTransformer}
      ${contrailCassandraConfig}
      ${contrailRabbitConfig}
      ${contrailZookeeperConfig}
    '';
  };

  contrailSvcMonitor = pkgs.writeTextFile {
    name = "contrail-svc-monitor.conf.ctmpl";
    text = contrailConfig ''
      [DEFAULTS]
      api_server_ip = ${contrailServices.api.dns}
      disc_server_ip = ${contrailServices.discovery.dns}
      disc_server_port = ${contrailServices.discovery.port}

      ${contrailLogConfig contrailServices.svcMonitor}
      ${contrailCassandraConfig}
      ${contrailRabbitConfig}
      ${contrailZookeeperConfig}

      [SCHEDULER]
      aaa_mode = no-auth
    '';
  };

  contrailControl = pkgs.writeTextFile {
    name = "contrail-control.conf.ctmpl";
    text = contrailConfig ''
      [DEFAULT]
      ${contrailLogConfig contrailServices.control}

      [IFMAP]
      {{ with secret "secret/opencontrail" -}}
      password = {{ .Data.ifmap_password }}
      {{- end }}
      user = ifmap

      [DISCOVERY]
      server = ${contrailServices.discovery.dns}
      port = ${contrailServices.discovery.port}
    '';
  };

  contrailCollector = pkgs.writeTextFile {
    name = "contrail-collector.conf.ctmpl";
    text = contrailConfig ''
      [DEFAULT]
      analytics_data_ttl = 48
      analytics_flow_ttl = 48
      analytics_statistics_ttl = 48
      analytics_config_audit_ttl = 48

      ${contrailLogConfig contrailServices.collector}
      ${contrailCassandraAnalyticsConfig}

      [COLLECTOR]
      server = ${containerIP}
      port = ${contrailServices.collector.port}

      [DISCOVERY]
      server = ${contrailServices.discovery.dns}
      port = ${contrailServices.discovery.port}

      [REDIS]
      server = ${contrailServices.redis.dns}
      port = ${contrailServices.redis.port}
    '';
  };

  contrailAnalyticsApi = pkgs.writeTextFile {
    name = "contrail-analytics-api.conf.ctmpl";
    text = contrailConfig ''
      [DEFAULT]
      host_ip = ${containerIP}
      rest_api_ip = ${containerIP}
      aaa_mode = no-auth
      partitions = 0

      ${contrailLogConfig contrailServices.analyticsApi}
      ${contrailCassandraAnalyticsConfig}

      [DISCOVERY]
      disc_server_ip = ${contrailServices.discovery.dns}
      disc_server_port = ${contrailServices.discovery.port}

      [REDIS]
      server = ${contrailServices.redis.dns}
      redis_server_port = ${contrailServices.redis.port}
      redis_query_port = ${contrailServices.redis.port}
      redis_uve_list = ${contrailServices.redis.dns}:${contrailServices.redis.port}
    '';
  };

}
