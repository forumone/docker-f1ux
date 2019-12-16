# How to build this file:
#   nix-build
#
# This is the default file used by nix-build. The result of building this file is a
# directory, named result/ by convention, that contains symbolic links to each of the
# Docker image tarballs produced by the derivations in images.nix.
#
# The directory's contents can be inspected or loaded into Docker via "docker load <$tag.tag.gz".
let
  pkgs = import <nixpkgs> {};
  inherit (pkgs) runCommand lib;

  images = import ./images.nix;

  # Creates a line of shell script that links the image pointed to by tag into $out
  linkImage = tag: ''
    ln -s ${images.${tag}} $out/${tag}.tar.gz
  '';

  # Creates the bash code necessary to link all image tags into $out - this has the effect
  # of asking Nix to build all image variations.
  linkAllImages = builtins.concatStringsSep
    "\n"
    (builtins.map linkImage (builtins.attrNames images));
in
runCommand "images" {} ''
  mkdir -p $out

  ${linkAllImages}
''
