pkgs:

let

  config = headers: conf: ''
    {{ $opencontrail := keyOrDefault "/config/opencontrail/data" "{}" | parseJSON -}}
  '' + headers
     + pkgs.lib.generators.toINI {} conf;

  logConfig = service: {
    log_level = ''{{- if $opencontrail.${service.name}.log_level }}
                    {{- $opencontrail.${service.name}.log_level }}
                  {{- else if $opencontrail.log_level }}
                    {{- $opencontrail.log_level }}
                  {{- else }}
                    SYS_INFO
                  {{- end }}'';
    log_local = 1;
  };

  ipList = { service, port ? 0, sep ? " "}: ''
    {{- range $index, $data := service "${service}" -}}
      {{- if $index }}${sep}{{ end }}{{- $data.Address -}}${if port > 0 then ":" + toString port else ""}
    {{- end }}'';

  secret = secret: ''
    {{- with secret "secret/opencontrail" -}}
      {{- .Data.${secret} }}
    {{- end }}'';

  catalogOpenstackHeader = ''
    {{ $openstack_region := env "openstack_region" -}}
    {{ $catalog := key (printf "/config/openstack/catalog/%s/data" $openstack_region) | parseJSON -}}
  '';

  identityAdminUrl = ''
    {{ with $catalog.identity.admin_url }}{{ . | regexReplaceAll "http://([^:/]+).*" "$1" }}{{ end }}'';

  cassandraConfig = {
    cassandra_server_list = ipList {
      service = "opencontrail-config-cassandra";
    };
  };

  cassandraAnalyticsConfig = {
    cassandra_server_list = ipList {
      service = "opencontrail-analytics-cassandra";
      port = 9042;
    };
  };

  rabbitConfig = {
    rabbit_server = ipList {
      service = "opencontrail-queue";
      sep = ", ";
    };
    rabbit_port = 5672;
    rabbit_user = "opencontrail";
    rabbit_password = secret "queue_password";
    rabbit_vhost = "opencontrail";
  };

  zookeeperConfig = {
    zk_server_port = 2181;
    zk_server_ip = ipList {
      service = "opencontrail-config-zookeeper";
      sep = ", ";
    };
  };

  keystoneConfig = {
    auth_host = identityAdminUrl;
    auth_port = 35357;
    auth_protocol = "http";
    admin_tenant_name = "service";
    admin_user = "opencontrail";
    admin_password = secret "service_password";
  };

  containerIP = ''{{- file "/my-ip" -}}'';

in rec {

  services = {
    api = {
      name = "api";
      dns = "opencontrail-api.service";
      port = 8082;
    };
    ifmap = {
      name = "ifmap";
      dns = "opencontrail-ifmap.service";
      port = 8443;
    };
    discovery = {
      name = "discovery";
      dns = "opencontrail-discovery.service";
      port = 5998;
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
      port = 8086;
    };
    analyticsApi = {
      name = "analytics_api";
    };
    redis = {
      name = "redis";
      dns = "opencontrail-redis.service";
      port = 6379;
    };
  };

  discovery = pkgs.writeTextFile {
    name = "contrail-discovery.conf.ctmpl";
    text = config "" {
      DEFAULTS = {
        listen_ip_addr = containerIP;
        listen_port = services.discovery.port;
        # minimim time to allow client to cache service information (seconds)
        ttl_min = 300;
        # maximum time to allow client to cache service information (seconds)
        ttl_max = 1800;
        # health check ping interval <=0 for disabling
        hc_interval = 5;
        # maximum hearbeats to miss before server will declare publisher out of service.
        hc_max_miss = 3;
        # use short TTL for agressive rescheduling if all services are not up
        ttl_short = 1;
      }
      // cassandraConfig
      // logConfig services.api;

      DNS-SERVER = {
        policy = "fixed";
      };
    };
  };

  api = pkgs.writeTextFile {
    name = "contrail-api.conf.ctmpl";
    text = config catalogOpenstackHeader {
      DEFAULTS = {
        listen_ip_addr = containerIP;
        # FIXME, the code is publishing ifmap_server_ip instead of listen_ip_addr to the discovery
        ifmap_server_ip = containerIP;
        listen_port = services.api.port;

        disc_server_ip = services.discovery.dns;
        disc_server_port = services.discovery.port;

        auth = "keystone";
        multi_tenancy = "True";
      }
      // cassandraConfig
      // rabbitConfig
      // zookeeperConfig
      // logConfig services.api;
      KEYSTONE = keystoneConfig;
      IFMAP_SERVER = {
        ifmap_listen_ip = containerIP;
        ifmap_listen_port = services.ifmap.port;
        ifmap_credentials = "ifmap:" + secret "ifmap_password";
      };
    };
  };

  schemaTransformer = pkgs.writeTextFile {
    name = "contrail-schema.conf.ctmpl";
    text = config "" {
      DEFAULTS = {
        api_server_ip = services.api.dns;
        disc_server_ip = services.discovery.dns;
        disc_server_port = services.discovery.port;
      }
      // logConfig services.schemaTransformer
      // cassandraConfig
      // rabbitConfig
      // zookeeperConfig;
    };
  };

  svcMonitor = pkgs.writeTextFile {
    name = "contrail-svc-monitor.conf.ctmpl";
    text = config "" {
      DEFAULTS = {
        api_server_ip = services.api.dns;
        disc_server_ip = services.discovery.dns;
        disc_server_port = services.discovery.port;
      }
      // logConfig services.svcMonitor
      // cassandraConfig
      // rabbitConfig
      // zookeeperConfig;

      SCHEDULER = {
        aaa_mode = "no-auth";
      };
    };
  };

  control = pkgs.writeTextFile {
    name = "contrail-control.conf.ctmpl";
    text = config "" {
      DEFAULT = logConfig services.control;

      IFMAP = {
        user = "ifmap";
        password = secret "ifmap_password";
      };

      DISCOVERY = {
        server = services.discovery.dns;
        port = services.discovery.port;
      };
    };
  };

  collector = pkgs.writeTextFile {
    name = "contrail-collector.conf.ctmpl";
    text = config "" {
      DEFAULT = {
        analytics_data_ttl = 48;
        analytics_flow_ttl = 48;
        analytics_statistics_ttl = 48;
        analytics_config_audit_ttl = 48;
      }
      // logConfig services.collector
      // cassandraAnalyticsConfig;

      COLLECTOR = {
        server = containerIP;
        port = services.collector.port;
      };

      DISCOVERY = {
        server = services.discovery.dns;
        port = services.discovery.port;
      };

      REDIS = {
        server = services.redis.dns;
        port = services.redis.port;
      };
    };
  };

  analyticsApi = pkgs.writeTextFile {
    name = "contrail-analytics-api.conf.ctmpl";
    text = config "" {
      DEFAULT = {
        host_ip = containerIP;
        rest_api_ip = containerIP;
        aaa_mode = "no-auth";
        partitions = 0;
      }
      // logConfig services.analyticsApi
      // cassandraAnalyticsConfig;

      DISCOVERY = {
        disc_server_ip = services.discovery.dns;
        disc_server_port = services.discovery.port;
      };

      REDIS = {
        server = services.redis.dns;
        redis_server_port = services.redis.port;
        redis_query_port = services.redis.port;
        redis_uve_list = services.redis.dns + ":" + toString services.redis.port;
      };
    };
  };

  vrouterAgent = pkgs.writeTextFile {
    name = "contrail-vrouter-agent.conf";
    text = pkgs.lib.generators.toINI {} {
      DEFAULT = {
        disable_flow_collection = 1;
        log_file = "/var/log/contrail/vrouter.log";
        log_level = "SYS_DEBUG";
        log_local = 1;
        collectors = "collector:" + toString services.collector.port;
      };
      CONTROL-NODE = {
        server = "control";
      };
      DISCOVERY = {
        port = toString services.discovery.port;
        server = "discovery";
      };
      FLOWS = {
        max_vm_flows = 20;
      };
      METADATA = {
        metadata_proxy_secret = "t96a4skwwl63ddk6";
      };
      TASK = {
        tbb_keepawake_timeout = 25;
      };
    };
  };
}
