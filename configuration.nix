pkgs:

{
discovery = pkgs.writeTextFile {
  name = "contrail-discovery.conf";
  text = ''
    [DEFAULTS]
    zk_server_ip=10.0.0.8
    zk_server_port=2181
    listen_ip_addr=0.0.0.0
    listen_port=5998
    log_local=True
    log_level=SYS_NOTICE
    cassandra_server_list = 10.0.0.2:9160
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
  name = "contrail-api.conf";
  text = ''
    [DEFAULTS]
    log_level = SYS_NOTICE
    log_local = 1
    cassandra_server_list = 10.0.0.2:9160
    disc_server_ip = 10.0.0.4
    disc_server_port = 5998

    rabbit_port = 5672
    rabbit_server = 10.0.0.7
    listen_port = 8082
    listen_ip_addr = 0.0.0.0
    zk_server_port = 2181
    zk_server_ip = 10.0.0.8

    [IFMAP_SERVER]
    ifmap_listen_ip = 0.0.0.0
    ifmap_listen_port = 8443
    ifmap_credentials = api-server:api-server
    '';
  };

control = pkgs.writeTextFile {
  name = "contrail-control.conf";
  text = ''
    [DEFAULT]
    log_file = /var/log/contrail/control.log
    log_local = 1
    log_level = SYS_DEBUG

    collectors=10.0.0.12:8086

    [IFMAP]
    server_url= https://10.0.0.3:8443
    password = api-server
    user = api-server

    [DISCOVERY]
    port = 5998
    server = 10.0.0.4
    '';
  };

collector = pkgs.writeTextFile {
  name = "contrail-collector.conf";
  text = ''
    [DEFAULT]
    analytics_data_ttl = 48
    analytics_flow_ttl = 48
    analytics_statistics_ttl = 48
    analytics_config_audit_ttl = 48

    log_file=/var/log/contrail/contrail-collector.log
    log_level=SYS_DEBUG
    log_local=1

    cassandra_server_list = 10.0.0.2:9042
    zookeeper_server_list = 10.0.0.8:2181
    http_server_port = 8089

    [COLLECTOR]
    server = 0.0.0.0
    port   = 8086

    [DISCOVERY]
    port = 5998
    server = 10.0.0.4

    [REDIS]
    server = 127.0.0.1
    port   = 6379

    [API_SERVER]
    api_server_list = 10.0.0.3:8082
    '';
  };

analytics-api = pkgs.writeTextFile {
  name = "contrail-analytics-api.conf";
  text = ''

    [DEFAULT]
    cassandra_server_list = 10.0.0.2:9042
    collectors = 127.0.0.1:8086
    http_server_port = 8090
    rest_api_port = 8081
    rest_api_ip = 0.0.0.0

    log_local = 1
    log_level = SYS_DEBUG
    log_file = /var/log/contrail/contrail-analytics-api.log

    api_server = 10.0.0.3:8082
    aaa_mode = no-auth
    partitions = 0

    [DISCOVERY]
    disc_server_ip = 10.0.0.4
    disc_server_port = 5998

    [REDIS]
    server= 127.0.0.1
    redis_server_port=6379
    redis_query_port=6379
    redis_uve_list = 127.0.0.1:6379
    '';   
  };
}		
