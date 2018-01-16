pkgs:

{
discovery = pkgs.writeTextFile {
  name = "contrail-discovery.conf.ctmpl";
  text = ''
    [DEFAULTS]

    zk_server_ip=zookeeper
    zk_server_port=2181

    listen_ip_addr=0.0.0.0
    listen_port=5998

    log_local=True
    log_level=SYS_NOTICE

    cassandra_server_list = cassandra:9160

    # minimim time to allow client to cache service information (seconds)
    ttl_min=300

    # maximum time to allow client to cache service information (seconds)
    ttl_max=1800

    # health check ping interval <=0 for disabling
    hc_interval=5

    # maximum hearbeats to miss before server will declare publisher out of
    # service.
    hc_max_miss=3

    # use short TTL for agressive rescheduling if all services are not up
    ttl_short=1

    [DNS-SERVER]
    policy=fixed
    '';
  };

api = pkgs.writeTextFile {
  name = "contrail-api.conf.ctmpl";
  text = ''

    [DEFAULTS]
    log_file = /var/log/contrail/api.log
    log_level = SYS_NOTICE
    log_local = 1

    cassandra_server_list = cassandra:9160
    disc_server_ip = discovery
    disc_server_port = 5998

    rabbit_port = 5672
    rabbit_server = openstack-queue
    rabbit_user = api

    {{ with secret "secret/api" -}}
    rabbit_password= {{ .Data.queue_password}}
    {{- end }}

    rabbit_vhost= openstack

    listen_port = 8082
    listen_ip_addr = 0.0.0.0

    zk_server_port = 2181
    zk_server_ip = zookeeper

    [IFMAP_SERVER]
    ifmap_listen_ip = 0.0.0.0
    ifmap_listen_port = 8443

    {{ with secret "secret/api" -}}
    ifmap_credentials = {{ .Data.ifmap_password}}:api-server
    {{- end }}
    '';
  };

control = pkgs.writeTextFile {
  name = "contrail-control.conf.ctmpl";
  text = ''
    [DEFAULT]
    log_file = /var/log/contrail/control.log
    log_local = 1
    log_level = SYS_DEBUG

    #collectors=collector:8086

    [IFMAP]
    server_url= https://api:8443

    {{ with secret "secret/control" -}}
    password ={{ .Data.ifmap_password}}
    {{- end }}
    user = api-server

    [DISCOVERY]
    port = 5998
    server = discovery
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

    log_file=/var/log/contrail/contrail-collector.log
    log_level=SYS_DEBUG
    log_local=1

    cassandra_server_list = cassandra:9042

    zookeeper_server_list = zookeeper:2181

    http_server_port = 8089

    [COLLECTOR]
    server = 0.0.0.0
    port   = 8086

    [DISCOVERY]
    port = 5998
    server = discovery

    [REDIS]
    server = redis
    port   = 6379

    [API_SERVER]
    api_server_list = api:8082
    '';
  };

analytics-api = pkgs.writeTextFile {
  name = "contrail-analytics-api.conf.ctmpl";
  text = ''
    [DEFAULT]

    cassandra_server_list = cassandra:9042

    collectors = collector:8086
    http_server_port = 8090

    rest_api_port = 8081
    rest_api_ip = 0.0.0.0

    log_local = 1
    log_level = SYS_DEBUG
    log_file = /var/log/contrail/contrail-analytics-api.log

    api_server = api:8082
    aaa_mode = no-auth
    partitions = 0

    [DISCOVERY]
    disc_server_ip = discovery
    disc_server_port = 5998

    [REDIS]
    server= redis
    redis_server_port=6379
    redis_query_port=6379
    redis_uve_list = redis:6379
    '';   
  };

schema-transformer = pkgs.writeTextFile {
  name = "contrail-schema.conf.ctmpl";
  text = ''
    [DEFAULTS]
    log_file = /var/log/contrail/contrail-schema.log
    log_local = 1
    log_level = SYS_DEBUG

    disc_server_ip = discovery
    disc_server_port = 5998

    rabbit_port = 5672
    rabbit_server = openstack-queue
    rabbit_user = schema

    {{ with secret "secret/schema" -}}
    rabbit_password= {{ .Data.queue_password}}
    {{- end }}

    rabbit_vhost= openstack

    zk_server_port = 2181
    zk_server_ip = zookeeper

    cassandra_server_list = cassandra:9160

    api_server_port = 8082
    api_server_ip = api
    '';
  };

svc-monitor = pkgs.writeTextFile {
  name = "contrail-svc-monitor.conf.ctmpl";
  text = ''
    [DEFAULTS]
    log_file = /var/log/contrail/svc-monitor.log
    log_level = SYS_DEBUG
    log_local = 1

    rabbit_port = 5672
    rabbit_server = openstack-queue
    rabbit_user = svc-monitor

    {{ with secret "secret/svc-monitor" -}}
    rabbit_password= {{ .Data.queue_password}}
    {{- end }}

    rabbit_vhost= openstack
    zk_server_port = 2181
    zk_server_ip = zookeeper

    cassandra_server_list = cassandra:9160

    disc_server_port = 5998
    disc_server_ip = discovery

    api_server_port = 8082
    api_server_ip = api
   
    [SCHEDULER]
    aaa_mode = no-auth
    '';
  };
}		
