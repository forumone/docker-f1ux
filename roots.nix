# How to build this file:
#   nix-build roots.nix -o roots
#
# This file creates a temporary root for the Nix garbage collector based on the builds
# for Node, PHP, and Ruby.
#
# This is useful during development to allow Nix to remove detritus while not purging the
# relatively expensive-to-build custom derivations.
#
# By passing "-o roots" to nix-build, we create a new symbolic link independent of the
# conventional "result" symbolic link, which allows us to keep both the images and the
# interpreters as roots during garbage collection.
let
  pkgs = import ./pkgs.nix;
  inherit (pkgs) writeText lib;

  # Things to build that we know aren't part of the upstream nixpkgs cache
  inherit (pkgs)
    git
    nodeVersions
    phpVersions
    ruby23 bundler2;

  # Gets all derivations from the attrset
  derivationsOf = attrs:
    builtins.filter lib.isDerivation (builtins.attrValues attrs);

  # The result of stringifying a derivation is the path in the Nix store
  derivationPath = drv: "${drv}";

  addRoots = builtins.concatMap (builtins.map derivationPath);
in
writeText
  "roots"
  (builtins.concatStringsSep
    "\n"
    (addRoots [
      [git ruby23 bundler2]
      (derivationsOf phpVersions)
      (derivationsOf nodeVersions)
    ]))
