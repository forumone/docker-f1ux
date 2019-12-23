let
  lib = import <nixpkgs/lib>;

  # Usage:
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

  # Usage:
  #   attrsToList { ... }
  #
  # Converts an attrset to a list of name/value pairs.
  #
  # The following identities should hold for all x:
  # 1. attrsToList (builtins.listToAttrs x) = x
  # 2. builtins.listToAttrs (attrsToList x) = x
  attrsToList = attrs:
    builtins.map
      (name: { inherit name; value = attrs.${name}; })
      (builtins.attrNames attrs);

  # Usage:
  #   crossProduct (x: y: ...) "" [[...] [...] [...]]
  #
  # Computs the cross product of an arbitrary number of lists. Generalization of nixpkgs'
  # lib.crossLists.
  crossProduct = f: nil: lists:
    builtins.foldl'
      (x: y: lib.crossLists f [x y])
      [nil]
      lists;

  # Usage:
  #   join "foo" "bar"
  #
  # Combines the two arguments with a hyphen. If x is the empty string, just outputs y.
  join = x: y:
    if x != "" then "${x}-${y}"
    else y;

  # Usage:
  #   tagMatrix [ { name = ...; versions = [...]; build = x: { ... }; }]
  #
  # Creates an attrset from a list of descriptions on how to produce a set of values from
  # a given version. This function is primarily intended for the case of building a Docker
  # image where the attrset's names represent the tags to use, and the values are an
  # attrset of derivations that depend on the elements.
  tagMatrix = builds:
    let
      # The default build function simply
      mkBuild = name: value: builtins.listToAttrs [
        { inherit name value; }
      ];

      mapper = { name, versions, build ? mkBuild name }:
        attrsToList (lib.mapAttrs'
          (key: drv: {
            name = join name key;
            value = build drv;
          })
          versions);

      inputs = builtins.map mapper builds;

      product = crossProduct
        (x: y: {
          name = join x.name y.name;
          value = x.value // y.value;
        })
        { name = ""; value = {}; }
        inputs;
    in
    builtins.listToAttrs product;
in
{
  inherit mkVersion mkVersions mkMatrix attrsToList crossProduct join tagMatrix;
}
