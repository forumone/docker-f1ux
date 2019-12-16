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
# interpreters as roots during garbage collection
let
  pkgs = import <nixpkgs> {};
  inherit (pkgs) runCommand;

  node = import ./node.nix;
  php = import ./php.nix;
  ruby = import ./ruby.nix;

  # The result of stringifying a derivation is the path in the Nix store
  derivationPath = drv: "${drv}";

  # Creates a list of string paths to the values in an attribute set
  derivationPaths = attrs: builtins.map derivationPath (builtins.attrValues attrs);
in
runCommand "temp-roots" {
  # These values are injected by Nix into the runCommand environment
  nodePaths = derivationPaths node;
  phpPaths = derivationPaths php;
  rubyPaths = derivationPaths ruby;
} ''
  for node in $nodePaths; do
    echo $node >> $out
  done

  for php in $phpPaths; do
    echo $php >> $out
  done

  for ruby in $rubyPaths; do
    echo $ruby >> $out
  done
''

