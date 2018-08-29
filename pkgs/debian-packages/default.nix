{ pkgs, contrailPkgs, lib, skydive }:

let debianPackageVersion = "3.2-6";
    vrouterUbuntu = module: lib.mkDebianPackage rec {
      name = "${module.name}.deb";
      version = debianPackageVersion;
      repository = "contrail";
      contents = [ module ];
      description = module.meta.description;
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

  vrouter_ubuntu_3_13_0_83_generic = vrouterUbuntu contrailPkgs.vrouter_ubuntu_3_13_0_83_generic;
  vrouter_ubuntu_3_13_0_112_generic = vrouterUbuntu contrailPkgs.vrouter_ubuntu_3_13_0_112_generic;
  vrouter_ubuntu_3_13_0_125_generic = vrouterUbuntu contrailPkgs.vrouter_ubuntu_3_13_0_125_generic;
  vrouter_ubuntu_3_13_0_141_generic = vrouterUbuntu contrailPkgs.vrouter_ubuntu_3_13_0_141_generic;
  vrouter_ubuntu_3_13_0_143_generic = vrouterUbuntu contrailPkgs.vrouter_ubuntu_3_13_0_143_generic;
  vrouter_ubuntu_4_4_0_101_generic = vrouterUbuntu contrailPkgs.vrouter_ubuntu_4_4_0_101_generic;

  contrailVrouterUserland = lib.mkDebianPackage rec {
    name = "contrail-vrouter-userland";
    version = debianPackageVersion;
    repository = "contrail";
    contents = [
      contrailPkgs.vrouterAgent contrailPkgs.vrouterPortControl
      contrailPkgs.vrouterUtils contrailPkgs.vrouterNetns ];
    description = "Vrouter userland programs (contrail-vrouter-agent, vrouter utilities, opencontrail-netns tools)";
    maintainerScripts = [
      (pkgs.writeScript "postinst" (builtins.readFile ./contrail/postinst))
      (pkgs.writeScript "postrm" (builtins.readFile ./contrail/postrm))
      (pkgs.writeText "contrail-vrouter-agent.upstart" (builtins.readFile ./contrail/contrail-vrouter-agent.upstart)) ];
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

