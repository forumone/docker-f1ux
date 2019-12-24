# How to build an image from this file:
#   nix-build f1ux.nix -A \"node-v10-php-7.1-ruby-2.3\"
#
# The escapes are needed since "node-v10-php-7.1-ruby-2.3" doesn't follow Nix's normal rules for attribute names
let
  pkgs = import <nixpkgs> {};
  inherit (pkgs) pkgsStatic runCommand lib dockerTools;

  util = import ./util.nix;

  # Import the various node/php/ruby versions we support
  nodeVersions = import ./node.nix;
  phpVersions = import ./php.nix;
  rubyVersions = import ./ruby.nix;

  # Builds the attrset of tag => { node grunt php composer ruby bundler } that varies
  # based on the node/php/ruby versions
  tags = util.tagMatrix [
    {
      name = "node";
      versions = nodeVersions;
      build = node: {
        inherit node;
        grunt = import ./grunt.nix { inherit node; };
      };
    }
    {
      name = "php";
      versions = phpVersions;
      build = php: {
        inherit php;
        composer = import ./composer.nix { inherit php; };
      };
    }
    {
      name = "ruby";
      versions = rubyVersions;
      build = ruby: {
        inherit ruby;
        bundler = import ./bundler.nix { inherit ruby; };
      };
    }
  ];

  # Utilities needed at runtime: bash, coreutils, and git. pkgs.cacert is needed for git
  # to be able to ls-remote against GitHub and other sources.
  utilities = with (pkgs); [
    bashInteractive
    coreutils
    git
    cacert
  ];

  # Development tools. These are used almost exclusively to be able to build and install
  # the ffi gem, which is transitively required by compass (ffi is required by rb_inotify)
  development = with (pkgs); [
    stdenv.cc
    gnumake
    gnused
    gnugrep
    gawk
    diffutils
    binutils
  ];

  # Creates /tmp in the image, which Composer needs for its cache.
  tempdir = runCommand "tmpdir" {} ''
    mkdir -p $out/tmp
    chmod 0777 $out/tmp
  '';

  # 1. Creates symlinks in /usr/bin as expected by libffi's configure script
  # 2. Puts 'ar' directly into the environment, as it's not part of pkgs.binutils
  #    (it's in pkgs.binutils-unwrapped, which causes issues if included directly due to
  #     ld and friends)
  symlinks = runCommand "symlinks" {} ''
    mkdir -p $out/usr/bin
    ln -s ${pkgs.file}/bin/file $out/usr/bin/file
    ln -s ${pkgs.coreutils}/bin/env $out/usr/bin/env

    mkdir -p $out/bin
    ln -s ${pkgs.binutils-unwrapped}/bin/ar $out/bin/ar
  '';

  # Paths and links to install into the image (see comments above)
  paths = [
    tempdir
    symlinks
  ];

  builder = tag: { ruby, ... }@packages:
    let
      runtimePath = builtins.concatStringsSep ":" [
        # Default $PATH in Docker images
        "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        # Make sure grunt is accessible
        "/lib/node_modules/.bin"
        # Make sure installed gem scripts (e.g., cap, compass) are accessible
        "${ruby}/bin"
      ];
    in
    dockerTools.buildLayeredImage {
      name = "forumone/f1ux";
      inherit tag;

      # Force nix to set the creation date to now for better discoverability by install
      # date (the default is a fixed date for image reproducibility reasons)
      created = "now";

      # This image has quite a few layers, so we ask nix to use most of the available
      # space when spreading images out.
      maxLayers = 120;

      # Concatenate the lists of things to install
      contents = builtins.concatLists [
        (builtins.attrValues packages)
        development
        utilities
        paths
      ];

      config = {
        # Set the default script to bash
        Cmd = "${pkgs.bashInteractive}/bin/bash";

        # Set the working directory to /app
        WorkingDir = "/app";

        # Add the updated $PATH and ask git to look at the installed cacert bundle
        Env = [
          "PATH=${runtimePath}"
          "GIT_SSL_CAPATH=/etc/ssl/certs/ca-bundle.crt"
          "GIT_SSL_CAINFO=/etc/ssl/certs/ca-bundle.crt"
        ];
      };
    };
in
builtins.mapAttrs builder tags
