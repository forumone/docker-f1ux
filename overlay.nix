# Overlay function to augment/replace various packages with customized derivations
self: super:
let
  nodeVersions = self.callPackage ./node.nix {};
  phpVersions = self.callPackage ./php.nix {};
in
{
  # Replace git with a smaller version - this is solely used by npm/composer to fetch
  # git-based dependencies, so most of the
  git = super.git.override {
    perlSupport = false;
    pythonSupport = false;
    withManual = false;
  };

  # Add utilities
  util = import ./util.nix { inherit (self) lib; };

  # Replace Ruby and Bundler with the custom derivation
  ruby23 = self.callPackage ./ruby.nix {};
  bundler2 = self.callPackage ./bundler.nix {};

  # Add prebuilt phantomjs
  inherit (self.callPackage ./phantomjs-prebuilt.nix {})
    phantomjs-prebuilt
    phantomjs-prebuilt_19;

  # Add paths expected by various tools (see comments in the referenced files)
  composerTemp = self.callPackage ./composerTemp.nix {};
  certPath = self.callPackage ./certPath.nix {};
  usrBinEnv = self.callPackage ./usrBinEnv.nix {};

  # Add node versions and expose shorthand for node & grunt
  inherit nodeVersions;
  inherit (nodeVersions)
    node12 grunt12
    node10 grunt10
    node8 grunt8
    node6 grunt6
    node4 grunt4;

  # Add PHP versions and expose shorthand for php & grunt
  inherit phpVersions;
  inherit (phpVersions)
    php74 composer74
    php73 composer73
    php72 composer72
    php71 composer71
    php70 composer70
    php56 composer56;

  # Add the image sets
  f1ux = self.callPackage ./f1ux {};
  gesso2 = self.callPackage ./gesso2 {};
}