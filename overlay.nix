# Overlay function to augment/replace various packages with customized derivations
self: super:
let
  nodeVersions = self.callPackage ./node.nix {};
  phpVersions = self.callPackage ./php.nix {};
in
{
  # Replace git with a smaller version - this is solely used by npm/composer to fetch
  # git-based dependencies, so most of the features that aren't plumbing-related (the
  # manual and stuff like interactive patching) can be safely omitted.
  git = super.git.override {
    perlSupport = false;
    pythonSupport = false;
    withManual = false;
  };

  # Full path to cacert's bundle. We save this here to avoid issues with keeping the
  # certificate paths in sync for the f1ux and gesso2 derivations.
  gitCertPath = "${self.cacert}/etc/ssl/certs/ca-bundle.crt";

  # Add utilities
  util = import ./util.nix { inherit (self) lib; };

  # Replace Ruby and Bundler with the custom derivation
  ruby23 = self.callPackage ./ruby.nix {};
  bundler2 = self.callPackage ./bundler.nix {};

  # Add the resolve-all-libraries command
  resolve-all-libraries = self.callPackage ./resolve-all-libraries.nix {};

  # Add paths expected by various tools (see comments in the referenced files)
  composerTemp = self.callPackage ./composerTemp.nix {};
  certPath = self.callPackage ./certPath.nix {};
  usrBinEnv = self.callPackage ./usrBinEnv.nix {};

  # Add PHP & node versions
  inherit nodeVersions;
  inherit phpVersions;

  # Add the image sets
  f1ux = self.callPackage ./f1ux {};
  gesso2 = self.callPackage ./gesso2 {};
}
