# DO NOT EDIT
# This file has been generated by
# $ ./tools/sources-from-github.sh

{pkgs}:
{
  # Head of branch R3.2-cloudwatt of repository github.com/cloudwatt/contrail-controller at 2018-08-30 12:20:34
  controller = pkgs.fetchFromGitHub {
    name = "controller";
    owner = "cloudwatt";
    repo = "contrail-controller";
    rev = "300f8d6a9524d326f674e7fe8f6fbc9c9b645495";
    sha256 = "183j4qm8qz532c8jpr25hzhgaki7wjn46cc4d04009mk3r6zfys8";
  };
  # Head of branch R3.2-cloudwatt of repository github.com/cloudwatt/contrail-neutron-plugin at 2018-08-30 12:20:46
  neutronPlugin = pkgs.fetchFromGitHub {
    name = "neutronPlugin";
    owner = "cloudwatt";
    repo = "contrail-neutron-plugin";
    rev = "6cc7dbc0246fbb9ab1c52a60f5a335e4dca7f692";
    sha256 = "1v2011hmyvs069x51nz2zdb5d9iwg08a5qw0kqd27j1p5qddq34v";
  };
  # Head of branch R3.2-cloudwatt of repository github.com/nlewo/contrail-vrouter at 2018-08-30 12:20:48
  vrouter = pkgs.fetchFromGitHub {
    name = "vrouter";
    owner = "nlewo";
    repo = "contrail-vrouter";
    rev = "005b2af10aa8ad5819e123f9ef596041dba8db5d";
    sha256 = "0pk8vhgskjnr9914n49ilzvpxiwxabmsf3cd8zqn80s4pkhbd78w";
  };
}
