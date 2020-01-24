# How to build an image from this file:
#   nix-build images/gesso2.nix -A \"node-v10-php-7.1-ruby-2.3\"
#
# The escapes are needed since "node-v10-php-7.1-ruby-2.3" doesn't follow Nix's normal rules for attribute names
let
  pkgs = import <nixpkgs> {};
  inherit (pkgs) pkgsStatic runCommand lib dockerTools;

  util = import ../util.nix;

  nodeVersions = import ../node.nix;
  phpVersions = import ../php.nix;

  # Creates the node+php matrix for Gesso 2.x-based images. Unlike f1ux, these images
  # don't need Ruby, so we've excluded quite a bit from them.
  tags = util.tagMatrix [
    {
      name = "node";
      versions = nodeVersions;
      build = node: {
        inherit node;
        grunt = import ../grunt.nix { inherit node; };
      };
    }
    {
      name = "php";
      versions = phpVersions;
      build = php: {
        inherit php;
        composer = import ../composer.nix { inherit php; };
      };
    }
  ];

  git = import ../git.nix;

  utilities = [
    pkgs.busybox
    # pkgs.cacert
    # git
  ];

  # Creates /tmp in the image, which Composer needs for its cache.
  tempdir = runCommand "tmpdir" {} ''
    mkdir -p $out/tmp
    chmod 0777 $out/tmp
  '';

  # Paths needed in the image (i.e., Composer's temp dir)
  paths = [ tempdir ];

  runtimePath = builtins.concatStringsSep ":" [
    # Default $PATH in Docker images
    "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    # Make sure grunt is accessible
    "/lib/node_modules/.bin"
  ];

  builder = tag: packages:
    dockerTools.buildLayeredImage {
      name = "forumone/gesso";
      tag = "2-${tag}";

      created = "now";

      contents = builtins.concatLists [
        (builtins.attrValues packages)
        utilities
        paths
      ];

      config = {
        Cmd = "${pkgs.busybox}/bin/sh";
        WorkingDir = "/app";
        Env = [
          "PATH=${runtimePath}"
          # "GIT_SSL_CAPATH=/etc/ssl/certs/ca-bundle.crt"
          # "GIT_SSL_CAINFO=/etc/ssl/certs/ca-bundle.crt"
        ];
      };
    };
in
builtins.mapAttrs builder tags
