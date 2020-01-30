{
  # Builders
  dockerTools, runCommand

  # Development tools & utilities needed in the image
, git, cacert
, stdenv
, bashInteractive, coreutils, file
, gnumake, gnused, gnugrep, gawk, diffutils, binutils, binutils-unwrapped

  # Paths
, composerTemp

  # Languages & tools
, node, grunt
, php, composer
, ruby23, bundler2

  # Library stuff
, util
}:
let
  # 1. Creates symlinks in /usr/bin as expected by libffi's configure script
  # 2. Puts 'ar' directly into the environment, as it's not part of binutils
  #    (it's in binutils-unwrapped, which causes issues if included directly due to
  #     ld and friends)
  symlinks = runCommand "symlinks" {} ''
    mkdir -p $out/usr/bin
    ln -s ${file}/bin/file $out/usr/bin/file
    ln -s ${coreutils}/bin/env $out/usr/bin/env

    mkdir -p $out/bin
    ln -s ${binutils-unwrapped}/bin/ar $out/bin/ar
  '';
in
dockerTools.buildLayeredImage {
  name = "forumone/f1ux";
  tag = util.combineKeys [node php ruby23];

  # Force nix to set the creation date to now for better discoverability by install
  # date (the default is a fixed date for image reproducibility reasons)
  created = "now";

  # Ask Nix to use more layers than the default when building this image, as there are a
  # lot of store paths to pack.
  maxLayers = 120;

  contents = [
    # Development & utilities
    # With the exception of git and cacert, everything here is needed in order to build
    # the FFI gem (compass -> rb-inotify -> ffi).
    git
    cacert
    stdenv.cc
    bashInteractive
    coreutils
    gnumake
    gnused
    gnugrep
    gawk
    diffutils
    binutils

    # Paths needed in the image
    composerTemp
    symlinks

    # Node.js
    node
    grunt

    # PHP
    php
    composer

    # Ruby
    ruby23
    bundler2
  ];

  config = {
    Cmd = "${bashInteractive}/bin/bash";

    WorkingDir = "/app";

    Env = [
      "PATH=${util.dockerPath}:${ruby}/bin"
      "GIT_SSL_CAPATH=/etc/ssl/certs/ca-bundle.crt"
      "GIT_SSL_CAINFO=/etc/ssl/certs/ca-bundle.crt"
    ];
  };
}
