# to run these tests:
# nix-instantiate --eval --strict -A test.lib
# if the resulting list is empty, all tests passed
{ pkgs, lib }:

with pkgs.lib;

runTests {

  testStdout = {
    expr = lib.fluentd.captureServiceStdout {
      fluentd = {
        source = {
          type = "stdout";
        };
      };
    };
    expected = true;
  };

  testNoStdout = {
    expr = lib.fluentd.captureServiceStdout {
      fluentd = {
        source = {
          type = "foo";
        };
      };
    };
    expected = false;
  };

  testStdoutSourceOutput = {
    expr = lib.fluentd.genFluentdSource {
      name = "svc";
      fluentd = {
        source = {
          type = "stdout";
        };
      };
    };
    expected = ''
      <source>
        format none
        path /tmp/svc
        tag log.svc
        @type named_pipe
      </source>
    '';
  };

  testOtherSourceOutput = {
    expr = lib.fluentd.genFluentdSource {
      name = "svc";
      fluentd = {
        source = {
          type = "syslog";
          protocol_type = "udp";
          message_format = "rfc3164";
          port = 1234;
          with_priority = true;
          include_source_host = false;
        };
      };
    };
    expected = ''
      <source>
        include_source_host false
        message_format rfc3164
        port 1234
        protocol_type udp
        tag log.svc
        @type syslog
        with_priority true
      </source>
    '';
  };

  testSourceParseSection = {
    expr = lib.fluentd.genFluentdSource {
      name = "svc";
      fluentd = {
        source = {
          type = "tail";
          parse = {
            type = "json";
            foo = "bar";
          };
        };
      };
    };
    expected = ''
      <source>
        <parse>
        foo bar
        @type json
        </parse>
        tag log.svc
        @type tail
      </source>
    '';
  };

  testInsertFluentd =
    let
      imageDesc = lib.fluentd.insertFluentd {
        services = [
          { name = "svc1"; }
          { name = "svc2"; }
        ];
      };
    in
      {
        expr = builtins.length imageDesc.services;
        expected = 2;
      };

  testInsertFluentd2 =
    let
      imageDesc = lib.fluentd.insertFluentd {
        services = [
          { name = "svc1"; }
          { name = "svc2"; fluentd = { source = { type = "stdout"; }; }; }
        ];
      };
    in
      {
        expr = builtins.length imageDesc.services;
        expected = 3;
      };

  testFilters = {
    expr = lib.fluentd.genFluentdFilters {
      name = "foo";
      fluentd.filters = [
        {
          type = "grep";
          regexp = [
            {
              key = "message";
              pattern = "cool";
            }
            {
              key = "hostname";
              pattern = "^web\d+\.example\.com$";
            }
          ];
        }
        {
          type = "parser";
          key_name = "message";
          parse = {
            type = "regexp";
            expression = ''
              /^(?<host>[^ ]*) [^ ]* (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^ ]*) +\S*)?" (?<code>[^ ]*) (?<size>[^ ]*)$/'';
            time_format = "%d/%b/%Y:%H:%M:%S %z";
          };
        }
      ];
    };
    expected = ''
      <filter log.foo>
        <regexp>
        key message
        pattern cool
        </regexp>
        <regexp>
        key hostname
        pattern ^webd+.example.com$
        </regexp>
        @type grep
      </filter>
      <filter log.foo>
        key_name message
        <parse>
        expression /^(?<host>[^ ]*) [^ ]* (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^ ]*) +\S*)?" (?<code>[^ ]*) (?<size>[^ ]*)$/
        time_format %d/%b/%Y:%H:%M:%S %z
        @type regexp
        </parse>
        @type parser
      </filter>
    '';
  };

  testFilterTag = {
    expr = lib.fluentd.genFluentdFilter "svc" {
      type = "grep";
      tag = "**";
      regexp = {
        key = "message";
        pattern = "cool";
      };
    };
    expected = ''
      <filter **>
        <regexp>
        key message
        pattern cool
        </regexp>
        @type grep
      </filter>
    '';
  };
}
