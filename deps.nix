pkgs:

{
  perp = pkgs.stdenv.mkDerivation {
    name = "perp";
    src = pkgs.fetchurl {
      url = http://b0llix.net/perp/distfiles/perp-2.07.tar.gz;
      sha256 = "05aq8xj9fpgs468dq6iqpkfixhzqm4xzj5l4lyrdh530q4qzw8hj";
    };
    preConfigure = "sed 's~ /usr/~ \${out}/usr/~' -i conf.mk";
  };
}
