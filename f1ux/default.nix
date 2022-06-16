{
  # Library functionality
  callPackage, lib

  # Custom language versions
, nodeVersions, phpVersions
}:
let
  nodeKeys = [ "14" "12" "10" "8" "6" "4" ];
  phpKeys = [ "56" "70" "71" "72" "73" "74" "80" ];

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
