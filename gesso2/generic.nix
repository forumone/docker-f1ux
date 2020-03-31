{
  # Builders
  dockerTools

  # Utilities
, git, busybox, fontconfig, phantomjs-prebuilt_19

  # Include explicitly
, glibc

  # Paths
, composerTemp, certPath, usrBinEnv

  # Languages & tools
, node, grunt
, php, composer

  # Library stuff
, util
}:
dockerTools.buildLayeredImage {
  name = "forumone/gesso";
  tag = "2-${util.combineKeys [node php]}";

  created = "now";

  contents = [
    glibc

    git
    busybox
    fontconfig.out
    phantomjs-prebuilt_19

    certPath
    composerTemp
    usrBinEnv

    node
    grunt

    php
    composer
  ];

  config = {
    Cmd = "${busybox}/bin/sh";
    WorkingDir = "/app";
    Env = [
      "PATH=${util.dockerPath}"
      "GIT_SSL_CAPATH=/etc/ssl/certs/ca-certificates.crt"
      "GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt"
    ];
  };
}
