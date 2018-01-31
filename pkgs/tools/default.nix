{ debianPackages, dockerImages, lib, pkgs, stdenv }:

{
  # This build an Ubuntu vm where Debian packages are
  # preinstalled. This is used to easily try generated Debian
  # packages.
  installDebianPackages = lib.runUbuntuVmScript [
    debianPackages.contrailVrouterUbuntu_3_13_0_83_generic
    debianPackages.contrailVrouterUserland
  ];

  loadContrailImages = with dockerImages; pkgs.writeShellScriptBin "load-contrail-images" ''
    for image in ${contrailApi} ${contrailDiscovery} ${contrailControl} ${contrailCollector} ${contrailAnalyticsApi} ${contrailSchemaTransformer} ${contrailSchemaTransformer} ${contrailSvcMonitor}
    do
      docker load -i $image
    done
  '';

  waitFor = stdenv.mkDerivation {
    name = "wait-for";
    src = pkgs.fetchFromGitHub {
      owner = "mrako";
      repo = "wait-for";
      rev = "d9699cb9fe8a4622f05c4ee32adf2fd93239d005";
      sha256 = "10fvdivpm8hr9ywaqyiv56nxrjbqkszmp6rj8zj3530gwdl8yddd";
    };
    buildInputs = [ pkgs.makeWrapper ];
    phases = [ "unpackPhase" "installPhase" "fixupPhase" ];
    installPhase = ''
      mkdir -p $out/bin
      cp wait-for $out/bin/
      chmod 755 $out/bin/wait-for
    '';
    postFixup = "wrapProgram $out/bin/wait-for --argv0 wait-for --set PATH ${pkgs.netcat}/bin:${pkgs.coreutils}/bin";
  };

}
