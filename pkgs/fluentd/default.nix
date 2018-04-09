{ stdenv, pkgs, bundlerEnv, ruby, curl }:

bundlerEnv {
  inherit ruby;

  pname = "fluentd";
  gemdir = ./.;
  gemConfig = pkgs.defaultGemConfig // {
    "cool.io" = attrs: {
      dontStrip = false;
    };
    msgpack = attrs: {
      buildInputs = [ pkgs.libmsgpack ];
      dontStrip = false;
    };
    "http_parser.rb" = attrs: {
      dontStrip = false;
    };
    mkfifo = attrs: {
      dontStrip = false;
    };
    strptime = attrs: {
      dontStrip = false;
    };
    "yajl-ruby" = attrs: {
      dontStrip = false;
    };
  };

  meta = with pkgs.lib; {
    description = "A data collector";
    homepage    = https://www.fluentd.org/;
    license     = licenses.asl20;
    maintainers = with maintainers; [ offline ];
    platforms   = platforms.unix;
  };
}
