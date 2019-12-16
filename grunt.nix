# Function to build grunt-cli using the custom-compiled static Node
{ node }:
let
  pkgs = import <nixpkgs> {};

  # These are the upstream nixpkgs' packages
  nodejs = pkgs.nodejs;
  grunt = pkgs.nodePackages.grunt-cli;

  # Swap the upstream node derivation with our custom one (see below)
  replaceNode = builtins.map (pkg: if pkg == nodejs then node else pkg);
in
grunt.overrideDerivation (old: {
  # Create a "patch" that replaces node in the derivation's inputs. The result of this is
  # identical to nixpkgs' grunt-clie, except that it is now linked to our custom Node
  # instead of nixpkgs' grunt
  buildInputs = replaceNode old.buildInputs;
})
