{ pkgs, contrailPkgs }:

let debianPackageVersion = "3.2-3";

    lib =  import ./lib pkgs;
    deps = import ./deps.nix pkgs;
in
{
  contrailVrouterUbuntu_3_13_0_83_generic = lib.mkDebianPackage rec {
    name = "contrail-vrouter-module-3-13-0-83-generic";
    version = debianPackageVersion;
    contents = contrailPkgs.contrailVrouter deps.ubuntuKernelHeaders_3_13_0_83_generic;
    description = "Contrail vrouter kernel module for kernel 3-13-0-83-generic";
    linkScript = ''
      vrouterRelativePath=$(find ${contents} -name vrouter.ko -printf '%P')
      vrouterRelativeDir=$(dirname $vrouterRelativePath)
      mkdir -p $vrouterRelativeDir

      vrouterPath=$(find ${contents} -name vrouter.ko)
      ln -s $vrouterPath $vrouterRelativeDir
    '';
  };

  contrailVrouterUserland = lib.mkDebianPackage rec {
    name = "contrail-vrouter-userland";
    version = debianPackageVersion;
    contents = [
      contrailPkgs.contrailVrouterAgent contrailPkgs.contrailVrouterPortControl
      contrailPkgs.contrailVrouterUtils contrailPkgs.contrailVrouterNetns ];
    description = "Vrouter userland programs (contrail-vrouter-agent, vrouter utilities, opencontrail-netns tools)";
    # This links all binaries files found in the contents to the
    # /usr/bin directory of the target system
    linkScript = ''
      for path in ${pkgs.lib.foldl (a: b: a + " " + b) "" contents};
      do
        find $path/bin/ -type f -not -name ".*" >> files
      done
      mkdir -p usr/bin
      echo "Link binaries found in contents"
      cat files | xargs -I'{}' -t ln -s '{}' usr/bin/
      rm files
    '';
    };
}
