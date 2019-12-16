# How to build an image from this file:
#   nix-build images.nix -A \"node-v10-php-7.1-ruby-2.3\"
#
# The escapes are needed since "node-v10-php-7.1-ruby-2.3" doesn't follow Nix's normal rules for attribute names
let
  pkgs = import <nixpkgs> {};
  inherit (pkgs) pkgsStatic runCommand lib dockerTools;

  # Import the various node/php/ruby versions we support
  nodeVersions = import ./node.nix;
  phpVersions = import ./php.nix;
  rubyVersions = import ./ruby.nix;

  # Helper to create iteration functions
  mkEach = obj: fn: builtins.map fn (builtins.attrNames obj);

  # Iteration functions for the versions
  eachNode = mkEach nodeVersions;
  eachPhp = mkEach phpVersions;
  eachRuby = mkEach rubyVersions;

  tags =
    let
      # This is an attribute set of node and php versions in each possible iteration -
      # that is, the keys are "node-(version)-php-(version)", such as "node-v4-php-7.3"
      # and "node-v10-php-7.3".
      # The values of the attribute set are an attrset of derivations to install into the
      # Docker image built below.
      node-php =
        builtins.concatLists
          (
            eachNode (
              nodeKey:
                eachPhp (
                  phpKey:
                    let
                      # Install node and grunt together
                      node = nodeVersions.${nodeKey};
                      grunt = import ./grunt.nix { inherit node; };

                      # Install PHP and composer together
                      php = phpVersions.${phpKey};
                      composer = import ./composer.nix { inherit php; };
                    in
                    {
                      name = "node-${nodeKey}-php-${phpKey}";
                      value = { inherit node grunt php composer; };
                    }
                )
            )
          );

      # This is the full combination of node, php, and ruby together. This is broken out
      # because the cross product of three lists is ugly to write, so it's (hopefully)
      # an improvement in readability to do it this way.
      node-php-ruby =
        builtins.concatLists
          (
            lib.forEach node-php
              (
                { name, value }: eachRuby (
                  rubyKey:
                    let
                      ruby = rubyVersions.${rubyKey};
                      bundler = import ./bundler.nix { inherit ruby; };
                    in
                    {
                      name = "${name}-ruby-${rubyKey}";
                      value = value // { inherit ruby bundler; };
                    }
                )
              )
          );
    in
    builtins.listToAttrs node-php-ruby;

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
in
builtins.mapAttrs
  (
    tag: { ruby, ... }@packages:
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
        name = "f1ux";
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
      }
  )
  tags
