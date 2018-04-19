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
    for image in ${contrailApi} ${contrailDiscovery} ${contrailControl} ${contrailCollector} ${contrailAnalyticsApi} ${contrailSchemaTransformer} ${contrailCollector} ${contrailQueryEngine} ${contrailSvcMonitor} ${contrailVrouter}
    do
      docker load -i $image
    done
  '';

  pushImage = pkgs.writeShellScriptBin "push-image" ''
    PATH=$1
    IMAGE_NAME=$2

    echo "Unzipping image..."
    ${pkgs.gzip}/bin/gzip -d $PATH -c > image.tar
    ${pkgs.skopeo}/bin/skopeo --insecure-policy copy docker-archive:image.tar docker://r.cwpriv.net/$IMAGE_NAME
    ${pkgs.coreutils}/bin/rm -f image.tar
  '';

}
