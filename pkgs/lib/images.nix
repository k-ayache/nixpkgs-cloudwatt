{ pkgs, ... }:

{

  kubernetesBaseImage = pkgs.dockerTools.pullImage {
    imageName = "docker-registry.sec.cloudwatt.com/kubernetes/base";
    imageTag = "16.04-861a9e3cd4c7cb3e";
    sha256 = "1q22fm4y5jc5bs6pcg6pcf26aaz6jqfdz5svv31ax2wmvza0r2l1";
  };

  consulAgentImage = pkgs.dockerTools.pullImage {
    imageName = "r.cwpriv.net/consul/agent";
    imageTag = "0.7.1-b6fcd21809bc2d5d";
    sha256 = "04bqni46rdp0hskrm9fvn51z6f0xjkjqzrz6l98344qw2k86gn98";
  };

  developmentDnsmaskImage = pkgs.dockerTools.pullImage {
    imageName = "r.cwpriv.net/eon/dnsmasq";
    imageTag = "no-recursion";
    sha256 = "05aaky7qh5gav5z7lh20qfskvzzbsvx5m3ng7b09pvswljdh9gpj";
  };

  developmentFluentdImage = pkgs.dockerTools.pullImage {
    imageName = "r.cwpriv.net/development/fluentd";
    imageTag = "20171002-7e3bdae6264cc689";
    sha256 = "09msv94m6q5rw21v26knggdcqzk5rczbvz8jxq7a0qmrrl38l58d";
  };

  developmentMysqlImage = pkgs.dockerTools.pullImage {
    imageName = "r.cwpriv.net/development/mysql";
    imageTag = "5.5.31-495193306c197c3a";
    sha256 = "1skysd3m6qwffqm0qj57b6diq5nfj409incq64c6lraac9yr39jz";
  };

  developmentPolipoImage = pkgs.dockerTools.pullImage {
    imageName = "r.cwpriv.net/development/polipo";
    imageTag = "1.1.1-70d89f5820626186";
    sha256 = "0901i5046byx1g4z2y8j9dpr0ym9zdx1gqhckqcl2x921chf4bb8";
  };

  developmentPolymurImage = pkgs.dockerTools.pullImage {
    imageName = "r.cwpriv.net/development/polymur";
    imageTag = "1.0.0-2d60d18e5effe989";
    sha256 = "0vmj292brss9mnd57l0l2fdc8iwva09dvrxjygbpkbcngz2n5nkh";
  };

  developmentRabbitmqImage = pkgs.dockerTools.pullImage {
    imageName = "r.cwpriv.net/development/rabbitmq";
    imageTag = "3.1.5-8bf69f128c8a0091";
    sha256 = "09ax2x70rznshy9wyfsxhb082cd3r7y2arqhw6lb21sp1j1nzhcq";
  };

  developmentRegistratorImage = pkgs.dockerTools.pullImage {
    imageName = "r.cwpriv.net/development/registrator";
    imageTag = "v7-fa2f257ec41d5d11";
    sha256 = "1vkky871wppwj1hf30ppaqkrn13p3alxcykdqyzvw34b91d0f71n";
  };

  developmentVaultImage = pkgs.dockerTools.pullImage {
    imageName = "r.cwpriv.net/development/vault";
    imageTag = "0.6.3-9943703ca6e78ba5";
    sha256 = "1bkjv3325n232il7qbra3a42s4ghn2a4npm3qp1kml7ckd7jzqxn";
  };

  openstackToolsImage = pkgs.dockerTools.pullImage {
    imageName = "r.cwpriv.net/openstack/tools";
    imageTag = "3.11.0-cf914ed23afae9b9";
    sha256 = "0ab1n323skzgmx4h6lkprard6prz07zn4dw8l6w0gpannn6ckp53";
  };

  keystoneAllImage = pkgs.dockerTools.pullImage {
    imageName = "r.cwpriv.net/keystone/all";
    imageTag = "9.0.0-61516ea9ed2202a1";
    sha256 = "1z944khvnp0z4mchnkxb5pgm9c29cll5v544jin596pwgrqbcw99";
  };

  zookeeperImage = pkgs.dockerTools.pullImage {
    imageName = "zookeeper";
    imageTag = "3.4.11";
    sha256 = "1g7vpw1yfdd4q70h7yzvksb68qvgq0fvj5qhq01sijs9dnmwzh6p";
  };

  cassandraImage = pkgs.dockerTools.pullImage {
    imageName = "cassandra";
    imageTag = "2.1.9";
    sha256 = "0y8p9c8k1y9vcrywj3nv2ckk93dlimjp6cjw6k21r2a6qcgfmmyq";
  };

}
