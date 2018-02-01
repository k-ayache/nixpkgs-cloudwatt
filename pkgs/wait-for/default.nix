{ stdenv, makeWrapper, fetchFromGitHub, netcat, coreutils }:

stdenv.mkDerivation {
  name = "wait-for";
  src = fetchFromGitHub {
    owner = "mrako";
    repo = "wait-for";
    rev = "d9699cb9fe8a4622f05c4ee32adf2fd93239d005";
    sha256 = "10fvdivpm8hr9ywaqyiv56nxrjbqkszmp6rj8zj3530gwdl8yddd";
  };
  buildInputs = [ makeWrapper ];
  phases = [ "unpackPhase" "installPhase" "fixupPhase" ];
  installPhase = ''
    mkdir -p $out/bin
    cp wait-for $out/bin/
    chmod 755 $out/bin/wait-for
  '';
  postFixup = "wrapProgram $out/bin/wait-for --argv0 wait-for --set PATH ${netcat}/bin:${coreutils}/bin";
}
