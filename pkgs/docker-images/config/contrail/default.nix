{ pkgs }:

let

  config = { headers ? "", conf }: ''
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

# Get the list of keys/values of openstack endpoints in JSON format

  catalogOpenstackHeader = ''
    {{ $openstack_region := env "openstack_region" -}}
    {{ $catalog := key (printf "/config/openstack/catalog/%s/data" $openstack_region) | parseJSON -}}
  '';

# Get keystone admin endpoint from the endpoints list in $catalog
  identityAdminHost = ''
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
    auth_host = identityAdminHost;
    auth_port = ''{{ if ($catalog.identity.admin_url | printf "%q") | regexMatch "(http:[^:]+:[0-9]+.*)" }}35357{{ else }}80{{ end }}'';
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
      dns = "opencontrail-analytics-api.service";
    };
    queryEngine = {
      name = "query_engine";
      dns = "opencontrail-query-engine.service";
    };
  };

  discovery = pkgs.writeTextFile {
    name = "contrail-discovery.conf.ctmpl";
    text = config {
      conf = {
        DEFAULTS = {
          listen_ip_addr = "0.0.0.0";
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
  };

  api = pkgs.writeTextFile {
    name = "contrail-api.conf.ctmpl";
    text = config {
      headers = catalogOpenstackHeader;
      conf = {
        DEFAULTS = {
          listen_ip_addr = containerIP;
          # FIXME, the code is publishing ifmap_server_ip instead of listen_ip_addr to the discovery
          ifmap_server_ip = containerIP;
          listen_port = services.api.port;

          disc_server_ip = services.discovery.dns;
          disc_server_port = services.discovery.port;

          auth = "keystone";
          aaa_mode = "cloud-admin";
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
  };

  schemaTransformer = pkgs.writeTextFile {
    name = "contrail-schema.conf.ctmpl";
    text = config {
      headers = catalogOpenstackHeader;
      conf = {
        DEFAULTS = {
          api_server_ip = services.api.dns;
          disc_server_ip = services.discovery.dns;
          disc_server_port = services.discovery.port;
        }
        // logConfig services.schemaTransformer
        // cassandraConfig
        // rabbitConfig
        // zookeeperConfig;
        KEYSTONE = keystoneConfig;
      };
    };
  };

  svcMonitor = pkgs.writeTextFile {
    name = "contrail-svc-monitor.conf.ctmpl";
    text = config {
      headers = catalogOpenstackHeader;
      conf = {
        DEFAULTS = {
          api_server_ip = services.api.dns;
          disc_server_ip = services.discovery.dns;
          disc_server_port = services.discovery.port;
        }
        // logConfig services.svcMonitor
        // cassandraConfig
        // rabbitConfig
        // zookeeperConfig;
        KEYSTONE = keystoneConfig;
      };
    };
  };

  vncApiLib = pkgs.writeTextFile {
    name = "vnc_api_lib.ini.ctmpl";
    text = config {
      headers = catalogOpenstackHeader;
      conf = {
        auth = {
          AUTHN_TYPE   = "keystone";
          AUTHN_PROTOCOL = "http";
          AUTHN_SERVER = keystoneConfig.auth_host;
          AUTHN_PORT   = keystoneConfig.auth_port;
          AUTHN_URL    = "/v2.0/tokens";
        };
      };
    };
  };


  control = pkgs.writeTextFile {
    name = "contrail-control.conf.ctmpl";
    text = config {
      conf = {
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
  };

  collector = pkgs.writeTextFile {
    name = "contrail-collector.conf.ctmpl";
    text = config {
      headers = catalogOpenstackHeader;
      conf = {
        DEFAULT = {
          analytics_data_ttl = 48;
          analytics_flow_ttl = 48;
          analytics_statistics_ttl = 48;
          analytics_config_audit_ttl = 48;
        }
        // logConfig services.collector
        // cassandraAnalyticsConfig;
        KEYSTONE = keystoneConfig;

        COLLECTOR = {
          server = containerIP;
          port = services.collector.port;
        };

        DISCOVERY = {
          server = services.discovery.dns;
          port = services.discovery.port;
        };
      };
    };
  };

  analyticsApi = pkgs.writeTextFile {
    name = "contrail-analytics-api.conf.ctmpl";
    text = config {
      conf = {
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
      };
    };
  };

  queryEngine = pkgs.writeTextFile {
    name = "contrail-query-engine.conf.ctmpl";
    text = config {
      conf = {
        DEFAULT = {
          hostip = containerIP;
        }
        // logConfig services.queryEngine
        // cassandraAnalyticsConfig;

        DISCOVERY = {
          server = services.discovery.dns;
          port = services.discovery.port;
        };
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

  vncApiLibVrouter = pkgs.writeTextFile {
    name = "vnc_api_lib.ini";
    text = ''
      [auth]
      AUTHN_TYPE   = keystone
      AUTHN_PROTOCOL = http
      AUTHN_SERVER = identity-admin.dev0.loc.cloudwatt.net
      AUTHN_PORT   = 35357
      AUTHN_URL    = /v2.0/tokens
    '';
  };

  fluentdForPythonService = {
    source = {
      type = "stdout";
    };
    filters = [
      {
        type = "parser";
        key_name = "message";
        parse = {
          type = "multi_format";
          pattern = [
            {
              format = "regexp";
              expression = ''/^(?<host>[^ ]*) [^ ]* (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^ ]*) +\S*)?" (?<code>[^ ]*) (?<size>[^ ]*) (?<response_time>\d+.\d+)(.*)?$/'';
              time_format = ''%Y-%m-%d %H:%M:%S'';
            }
            {
              format = "regexp";
              expression = ''/^(?<time>([^ ]+ ){3})[^\:]+: (?<message>.*)$/'';
              time_format = ''%m/%d/%Y %I:%M:%S %p'';
            }
            {
              format = "regexp";
              expression = ''/^(?<level>\w+):(?<message>.*)$/'';
            }
            {
              format = "none";
            }
          ];
        };
      }
    ];
  };

  fluentdForCService = {
    source = {
      type = "stdout";
    };
    filters = [
      {
        type = "parser";
        key_name = "message";
        parse = {
          type = "multi_format";
          pattern = [
            {
              format = "regexp";
              expression = ''/^(?<time>[^:]+:[^:]+:[^:]+):[^\[]+\[[^ ]+ (?<thread>[^,]+), [^ ]+(?<pid>[^\]]+)\]: (?<message>.*)$/'';
              time_format = ''%Y-%m-%d %a %H:%M:%S'';
            }
            {
              format = "none";
            }
          ];
        };
      }
    ];
  };
}
