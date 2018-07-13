{ pkgs, contrailPkgs, lib, deps, skydive }:

let debianPackageVersion = "3.2-5";
    contrailVrouterUbuntu = kernel: lib.mkDebianPackage rec {
      name = "contrail-vrouter-module-${kernel.version}";
      version = debianPackageVersion;
      repository = "contrail";
      contents = [ (contrailPkgs.lib.buildVrouter kernel) ];
      description = "Contrail vrouter kernel module for kernel ${kernel.version}";
      script = ''
        vrouterRelativePath=$(find ${pkgs.lib.concatStrings contents} -name vrouter.ko -printf '%P')
        vrouterRelativeDir=$(dirname $vrouterRelativePath)
        mkdir -p $vrouterRelativeDir

        vrouterPath=$(find ${pkgs.lib.concatStrings contents} -name vrouter.ko)
        ln -s $vrouterPath $vrouterRelativeDir
      '';
    };
in
{

  contrailVrouterUbuntu_3_13_0_83_generic = contrailVrouterUbuntu deps.ubuntuKernelHeaders_3_13_0_83_generic;
  contrailVrouterUbuntu_3_13_0_112_generic = contrailVrouterUbuntu deps.ubuntuKernelHeaders_3_13_0_112_generic;
  contrailVrouterUbuntu_3_13_0_125_generic = contrailVrouterUbuntu deps.ubuntuKernelHeaders_3_13_0_125_generic;
  contrailVrouterUbuntu_3_13_0_141_generic = contrailVrouterUbuntu deps.ubuntuKernelHeaders_3_13_0_141_generic;
  contrailVrouterUbuntu_3_13_0_143_generic = contrailVrouterUbuntu deps.ubuntuKernelHeaders_3_13_0_143_generic;
  contrailVrouterUbuntu_4_4_0_101_generic = contrailVrouterUbuntu deps.ubuntuKernelHeaders_4_4_0_101_generic;

  contrailVrouterUserland = lib.mkDebianPackage rec {
    name = "contrail-vrouter-userland";
    version = debianPackageVersion;
    repository = "contrail";
    contents = [
      contrailPkgs.vrouterAgent contrailPkgs.vrouterPortControl
      contrailPkgs.vrouterUtils contrailPkgs.vrouterNetns ];
    description = "Vrouter userland programs (contrail-vrouter-agent, vrouter utilities, opencontrail-netns tools)";
    # This links all binaries files found in the contents to the
    # /usr/bin directory of the target system
    script = ''
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

  skydive = lib.mkDebianPackage rec {
    name = "skydive";
    version = "${skydive.version}-1";
    description = skydive.meta.description;
    script = ''
      mkdir -p usr/bin/
      cp ${skydive}/bin/skydive usr/bin/
    '';
  };
}

