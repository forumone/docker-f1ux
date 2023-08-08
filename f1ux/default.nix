{
  # Library functionality
  callPackage, lib

  # Custom language versions
, nodeVersions, phpVersions
}:
let
  nodeKeys = [ "14" "12" "10"];
  phpKeys = [ "74" "80" "81" "82" ];

  mkImage = nodeKey: phpKey:
    let
      node = nodeVersions.${"node${nodeKey}"};
      grunt = nodeVersions.${"grunt${nodeKey}"};

      php = phpVersions.${"php${phpKey}"};
      composer = phpVersions.${"composer${phpKey}"};
    in
    {
      name = "node${nodeKey}-php${phpKey}";
      value = callPackage ./generic.nix {
        inherit node grunt php composer;
      };
    };
in
builtins.listToAttrs (lib.crossLists mkImage [nodeKeys phpKeys])
