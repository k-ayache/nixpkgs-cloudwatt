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
}

