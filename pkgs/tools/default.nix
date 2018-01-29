{ debianPackages, dockerImages, lib, pkgs }:

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
}
