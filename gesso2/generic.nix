{
  # Builders
  dockerTools

  # Utilities
, git, busybox

  # Support for PhantomJS & friends
, fontconfig
, resolve-all-libraries

  # Include explicitly
, glibc

  # Paths
, composerTemp, certPath, usrBinEnv
, gitCertPath

  # Languages & tools
, node, grunt
, php, composer
, phpVersions

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
    resolve-all-libraries

    certPath
    composerTemp
    usrBinEnv

    node
    grunt

    (phpVersions.removeMemoryLimit php)
    composer
  ];

  config = {
    Cmd = "${busybox}/bin/sh";
    WorkingDir = "/app";
    Env = [
      "PATH=${util.dockerPath}"
      "GIT_SSL_CAPATH=${gitCertPath}"
      "GIT_SSL_CAINFO=${gitCertPath}"
    ];
  };
}
