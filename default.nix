# How to build this file:
#   nix-build
#
# How to build this file, selecting only one set of images:
#   nix-build --argstr key f1ux
#
# This is the default file used by nix-build. The result of building this file is a
# shell script, symbolically linked in ./result, that loads all of the requested images
# into Docker.
{ key ? null }:
let
  pkgs = import <nixpkgs> {};
  inherit (pkgs) writeShellScript lib;

  imageSets = import ./images;

  # Loads a single set of images from the image sets in ./images/default.nix
  loadImages = images:
    builtins.concatStringsSep
      "\n"
      (lib.mapAttrsToList (_: image: "docker load <${image}") images);

  loadAllImages = imagesets:
    builtins.concatStringsSep
      ""
      (lib.mapAttrsToList
        (name: images:
          ''
            # ${name}
            ${loadImages images}
          '')
        imagesets);

  isRequestedImageSet =
    let
      namePredicate =
        if key == null
        then lib.const true
        else name: name == key;
    in
    name: _: namePredicate name;

  scriptText = loadAllImages (lib.filterAttrs isRequestedImageSet imageSets);
in
writeShellScript "loadAll" scriptText
