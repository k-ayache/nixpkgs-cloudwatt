{
  "cool.io" = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "03wwgs427nmic6aa365d7kyfbljpb1ra6syywffxfmz9382xswcp";
      type = "gem";
    };
    version = "1.5.3";
  };
  fluent-plugin-concat = {
    dependencies = ["fluentd"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0kk8r6ii72hyhy56jg02afkxs89blsj4yfjz9yy142ia4hylgkx0";
      type = "gem";
    };
    version = "2.2.0";
  };
  fluent-plugin-detect-exceptions = {
    dependencies = ["fluentd"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1sxg76vphyxi2jkmjaxnsvvh9bm5c1va4781631k3hxrnn2s0mag";
      type = "gem";
    };
    version = "0.0.9";
  };
  fluent-plugin-multi-format-parser = {
    dependencies = ["fluentd"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "15xawrl6cc69arcsajd5f0l5flhyhnx2w91cd051y8hvhggy9kcs";
      type = "gem";
    };
    version = "1.0.0";
  };
  fluent-plugin-named_pipe = {
    dependencies = ["fluentd" "mkfifo"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0kijxwlaqnhraxjwx7q81vdgl1gm6j4wrlxr3n79lcdl7d3hkwxj";
      type = "gem";
    };
    version = "0.2.0";
  };
  fluent-plugin-prometheus = {
    dependencies = ["fluentd" "prometheus-client"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "10pm2dmh35px4dd434lknb7db438gg8hslzzjkzz8z0ag70h9pha";
      type = "gem";
    };
    version = "1.0.1";
  };
  fluent-plugin-rewrite-tag-filter = {
    dependencies = ["fluentd"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1qdarb1anbdl6f3r52x4z2g998n41334hhd5bx3njn1lnmp5rgwy";
      type = "gem";
    };
    version = "2.0.2";
  };
  fluentd = {
    dependencies = ["cool.io" "http_parser.rb" "msgpack" "ruby_dig" "serverengine" "sigdump" "strptime" "tzinfo" "tzinfo-data" "yajl-ruby"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1wkab48zahbdhnp6gwagszhyx15yabnvv1b9kzv7h2v7bdxmfmh7";
      type = "gem";
    };
    version = "0.14.25";
  };
  "http_parser.rb" = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "15nidriy0v5yqfjsgsra51wmknxci2n2grliz78sf9pga3n0l7gi";
      type = "gem";
    };
    version = "0.6.0";
  };
  mkfifo = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0s81d7vc12cdq0pkxg7gf4spxn23lzw1pmhlqgx1xd9c59i1n0k5";
      type = "gem";
    };
    version = "0.1.1";
  };
  msgpack = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "09xy1wc4wfbd1jdrzgxwmqjzfdfxbz0cqdszq2gv6rmc3gv1c864";
      type = "gem";
    };
    version = "1.2.4";
  };
  prometheus-client = {
    dependencies = ["quantile"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0s5acyq7mzd8dp80azfxx5z5z3iipw8493xkxqafb5w2r1g30625";
      type = "gem";
    };
    version = "0.7.1";
  };
  quantile = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0fapsaq5hz8b7rbnmz5n31nzv5vqajwsb24lhjx664rx6l6mc4ml";
      type = "gem";
    };
    version = "0.2.0";
  };
  ruby_dig = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1qcpmf5dsmzxda21wi4hv7rcjjq4x1vsmjj20zpbj5qg2k26hmp9";
      type = "gem";
    };
    version = "0.0.2";
  };
  serverengine = {
    dependencies = ["sigdump"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0jkn32ly86p9g5xw87v7209q55sl2529q80kc70q2vvbrhlk4gww";
      type = "gem";
    };
    version = "2.0.6";
  };
  sigdump = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1mqf06iw7rymv54y7rgbmfi6ppddgjjmxzi3hrw658n1amp1gwhb";
      type = "gem";
    };
    version = "0.2.4";
  };
  strptime = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1avbl1fj4y5qx9ywkxpcjjxxpjj6h7r1dqlnddhk5wqg6ypq8lsb";
      type = "gem";
    };
    version = "0.1.9";
  };
  thread_safe = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0nmhcgq6cgz44srylra07bmaw99f5271l0dpsvl5f75m44l0gmwy";
      type = "gem";
    };
    version = "0.3.6";
  };
  tzinfo = {
    dependencies = ["thread_safe"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1fjx9j327xpkkdlxwmkl3a8wqj7i4l4jwlrv3z13mg95z9wl253z";
      type = "gem";
    };
    version = "1.2.5";
  };
  tzinfo-data = {
    dependencies = ["tzinfo"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0iqz29aavkgbysx4d3lb5358qviirwj8m7ygzj2ka5lr099gwawr";
      type = "gem";
    };
    version = "1.2018.3";
  };
  yajl-ruby = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1rn4kc9fha990yd252wglh6rcyh35cavm1vpyfj8krlcwph09g30";
      type = "gem";
    };
    version = "1.3.1";
  };
}