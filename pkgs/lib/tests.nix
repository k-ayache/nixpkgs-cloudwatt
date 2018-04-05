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

  testAddFluentdService1 =
    let
      services = [ { name = "svc"; } ];
    in
      {
        expr = builtins.length (lib.fluentd.addFluentdService services);
        expected = 1;
      };

  testAddFluentdService2 =
    let
      services = [ { name = "svc1"; } { name = "svc2";} ];
    in
      {
        expr = builtins.length (lib.fluentd.addFluentdService services);
        expected = 2;
      };

  testAddFluentdService3 =
    let
      services = [ { name = "svc1"; } { name = "svc2"; fluentd = { source = { type = "stdout"; }; }; } ];
    in
      {
        expr = builtins.length (lib.fluentd.addFluentdService services);
        expected = 3;
      };

}
