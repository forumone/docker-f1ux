{
  # Builders
  dockerTools

  # Utilities
, git, busybox

  # Paths
, composerTemp, certPath

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
    git
    busybox
    certPath
    composerTemp

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
      "GIT_SSL_CAPATH=/etc/ssl/certs/ca-bundle.crt"
      "GIT_SSL_CAINFO=/etc/ssl/certs/ca-bundle.crt"
    ];
  };
}
