{ pkgs, stdenv, lib, buildGoPackage, fetchFromGitHub, perl
, go-bindata, libxml2, protobuf3_1, libpcap, pkgconfig, go-protobuf, glibc
, enableStatic ? false, zlibStatic }:

let
  # Will not be required anymore on nixos 18.09
  libxml2Static = (libxml2.overrideAttrs (old: {
    outputs = old.outputs ++ ["static"];
    configureFlags = old.configureFlags ++ ["--enable-static"];
    postFixup = old.postFixup + ''moveToOutput lib/libxml2.a "$static"'';
  })).static;

  staticLibs = builtins.concatStringsSep " " [
    "${glibc.static}/lib/libc.a"
    "${glibc.static}/lib/libpthread.a"
    "${glibc.static}/lib/libm.a"
    "${libxml2Static}/lib/libxml2.a"
    "${zlibStatic.static}/lib/libz.a"];
in

buildGoPackage rec {
  name = "skydive-${version}";
  version = "0.18.0";
  goPackagePath = "github.com/skydive-project/skydive";

  src = fetchFromGitHub {
    owner = "skydive-project";
    repo = "skydive";
    rev = "v${version}";
    sha256 = "0b3lynw3ccr2csd8l326ymd3317a2b6ki5cql03zdzyf2phlj7v1";
  };

  prePatch = ''
    substituteInPlace Makefile \
      --replace ".proto: builddep" ".proto: " \
      --replace ".bindata: builddep" ".bindata: "
  '';

  excludedPackages = "contrib/snort";

  buildInputs = [ perl go-bindata go-protobuf protobuf3_1 libpcap pkgconfig libxml2 ]
    ++ (pkgs.lib.optional enableStatic [ glibc.static libxml2Static ]);

  goDeps = ./deps.nix;

  preBuild = ''
    make -C go/src/github.com/skydive-project/skydive genlocalfiles VERSION=${version}
    buildFlagsArray="-ldflags=-X github.com/skydive-project/skydive/version.Version=${version}"
  '' + pkgs.lib.optionalString enableStatic ''
    buildFlagsArray+=" -extldflags \"-static ${staticLibs}\""'';

  preInstall = ''
    mkdir -p $out/share/skydive
    cp go/src/github.com/skydive-project/skydive/etc/skydive.yml.default $out/share/skydive/
  '';

  meta = {
    homepage = http://skydive.network;
    description = "A real-time network analyzer";
    licenses = [ lib.licenses.asl20 ];
    platforms = [ "x86_64-linux" ];
    maintainers = [ lib.maintainers.lewo ];
  };
}
