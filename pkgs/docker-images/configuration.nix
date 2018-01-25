pkgs:

{
discovery = pkgs.writeTextFile {
  name = "contrail-discovery.conf.ctmpl";
  text = ''
    [DEFAULTS]
    listen_ip_addr = 0.0.0.0
    listen_port = 5998

    log_level = SYS_INFO
    log_local = 1

    cassandra_server_list = {{ range $data := service "opencontrail-config-cassandra" }}{{$data.Address}} {{ end }}

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

    [DNS-SERVER]
    policy=fixed
    '';
  };

api = pkgs.writeTextFile {
  name = "contrail-api.conf.ctmpl";
  text = ''

    [DEFAULTS]
    log_level = SYS_INFO
    log_local = 1

    cassandra_server_list = {{ range $data := service "opencontrail-config-cassandra" }}{{$data.Address}} {{ end }}
    disc_server_ip = discovery
    disc_server_port = 5998

    rabbit_server = {{ range $index, $data := service "opencontrail-queue" }}{{if $index}},{{end}}{{$data.Address}}{{ end }}
    rabbit_port = 5672
    rabbit_user = opencontrail
    rabbit_password = {{ with secret "secret/opencontrail" -}}{{ .Data.queue_password }}{{- end }}
    rabbit_vhost = opencontrail

    listen_port = 8082
    listen_ip_addr = 0.0.0.0

    zk_server_port = 2181
    zk_server_ip = {{ range $index, $data := service "opencontrail-config-zookeeper" }}{{if $index}},{{end}}{{$data.Address}}{{ end }}

    [IFMAP_SERVER]
    ifmap_listen_ip = 0.0.0.0
    ifmap_listen_port = 8443

    {{ with secret "secret/opencontrail" -}}
    ifmap_credentials = ifmap:{{ .Data.ifmap_password}}
    {{- end }}
    '';
  };

control = pkgs.writeTextFile {
  name = "contrail-control.conf.ctmpl";
  text = ''
    [DEFAULT]
    log_level = SYS_INFO
    log_local = 1

    [IFMAP]
    {{ with secret "secret/opencontrail" -}}
    password = {{ .Data.ifmap_password}}
    {{- end }}
    user = ifmap

    [DISCOVERY]
    port = 5998
    server = opencontrail-discovery.service 
    '';
  };

collector = pkgs.writeTextFile {
  name = "contrail-collector.conf.ctmpl";
  text = ''
    [DEFAULT]
    analytics_data_ttl = 48
    analytics_flow_ttl = 48
    analytics_statistics_ttl = 48
    analytics_config_audit_ttl = 48

    log_level = SYS_INFO
    log_local = 1

    cassandra_server_list = {{ range $data := service "opencontrail-analytics-cassandra" }}{{$data.Address}}:9042 {{ end }}

    [COLLECTOR]
    server = 0.0.0.0
    port = 8086

    [DISCOVERY]
    server = opencontrail-discovery.service
    port = 5998

    [REDIS]
    server = opencontrail-redis.service
    port = 6379
    '';
  };

analytics-api = pkgs.writeTextFile {
  name = "contrail-analytics-api.conf.ctmpl";
  text = ''
    [DEFAULT]
    rest_api_ip = 0.0.0.0

    cassandra_server_list = {{ range $data := service "opencontrail-analytics-cassandra" }}{{$data.Address}}:9042 {{ end }}

    log_level = SYS_INFO
    log_local = 1

    aaa_mode = no-auth
    partitions = 0

    [DISCOVERY]
    disc_server_ip = opencontrail-discovery.service
    disc_server_port = 5998

    [REDIS]
    server = opencontrail-redis.service
    redis_server_port = 6379
    redis_query_port = 6379
    redis_uve_list = opencontrail-redis.service:6379
    '';
  };

schema-transformer = pkgs.writeTextFile {
  name = "contrail-schema.conf.ctmpl";
  text = ''
    [DEFAULTS]
    log_level = SYS_INFO
    log_local = 1

    api_server_ip = opencontrail-api.service

    disc_server_ip = opencontrail-discovery.service
    disc_server_port = 5998

    rabbit_server = {{ range $index, $data := service "opencontrail-queue" }}{{if $index}},{{end}}{{$data.Address}}{{ end }}
    rabbit_port = 5672
    rabbit_user = opencontrail
    rabbit_password = {{ with secret "secret/opencontrail" -}}{{ .Data.queue_password }}{{- end }}
    rabbit_vhost = opencontrail

    zk_server_port = 2181
    zk_server_ip = {{ range $index, $data := service "opencontrail-config-zookeeper" }}{{if $index}},{{end}}{{$data.Address}}{{ end }}

    cassandra_server_list = {{ range $data := service "opencontrail-config-cassandra" }}{{$data.Address}} {{ end }}
    '';
  };

svc-monitor = pkgs.writeTextFile {
  name = "contrail-svc-monitor.conf.ctmpl";
  text = ''
    [DEFAULTS]
    log_level = SYS_INFO
    log_local = 1

    api_server_ip = opencontrail-api.service

    rabbit_server = {{ range $index, $data := service "opencontrail-queue" }}{{if $index}},{{end}}{{$data.Address}}{{ end }}
    rabbit_port = 5672
    rabbit_user = opencontrail
    rabbit_password = {{ with secret "secret/opencontrail" -}}{{ .Data.queue_password }}{{- end }}
    rabbit_vhost = opencontrail

    zk_server_ip = {{ range $index, $data := service "opencontrail-config-zookeeper" }}{{if $index}},{{end}}{{$data.Address}}{{ end }}
    zk_server_port = 2181

    cassandra_server_list = {{ range $data := service "opencontrail-config-cassandra" }}{{$data.Address}} {{ end }}

    disc_server_port = 5998
    disc_server_ip = opencontrail-discovery.service

    [SCHEDULER]
    aaa_mode = no-auth
    '';
  };
}		
