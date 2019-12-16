let
  lib = import <nixpkgs/lib>;

  # Example usage:
  #   builtins..map (mkVersion { key = str: ...; }) [...]
  #
  # This creates a helper function that extracts a key from a version, and is intended
  # to be used to simplify management of derivations. The idea is that, given a version
  # like "1.2.3", the key function can be used to return "1" or "1.2", which is a more
  # human-friendly key.
  #
  # The return value of the created helper is a name/value attrset, suitably as an element
  # of the list passed to builtins.listToAttrs.
  mkVersion =
    { key }:
    { version, sha256 }:
    let
      name = key version;
    in
    {
      inherit name;
      value = { inherit name version sha256; };
    };

  # Usage:
  #   mkVersions { key = str: ...; } [...]
  #
  # This function returns an attrset where the attrset's keys are derived from the full
  # version - for PHP, one might find a key of "7.1" pointing to { name = "7.1.33"; },
  # for example.
  mkVersions =
    { key }:
    versions:
    builtins.listToAttrs (builtins.map (mkVersion { inherit key; }) versions);

  # Usage:
  #  mkMatrix { key = str: ..., mkDerivation = {...}: ..., versions = [...]; }
  #
  # This function creates a full attrset of human-friendly keys mapped to the full Nix
  # derivation created by the mkDerivation function. The difference between this and
  # mkVersions is that mkVersions doesn't create a full derivation - just the metadata
  # needed to construct an 'src' attribute.
  mkMatrix =
    { key, mkDerivation, versions }:
    let
      versionAttrs = mkVersions { inherit key; } versions;
    in
    builtins.mapAttrs (lib.const mkDerivation) versionAttrs;
in
{
  inherit mkVersion mkVersions mkMatrix;
}
