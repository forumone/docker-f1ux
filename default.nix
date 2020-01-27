# Build all images (f1ux and gesso 2.x):
#   nix-build
#
# Build only f1ux images:
#   nix-build -A f1ux
#
# Build only gesso 2.x images:
#   nix-build -A gesso2
let
  pkgs = import ./pkgs.nix;
  inherit (pkgs) lib f1ux gesso2;

  # Retrieves the Docker images from an attrset (i.e., pkgs.f1ux or pkgs.gesso2)
  getImages = imageSet:
    builtins.filter
      lib.isDerivation
      (builtins.attrValues imageSet);

  # Single line of shell script to load a Docker image
  loadImage = drv: "docker load <${drv}";

  # Creates a shell script to load the image sets passed in as imageSets
  loadImages = imageSet:
      pkgs.writeShellScript
        "loadImages"
        (lib.concatMapStringsSep "\n" loadImage (getImages imageSet));
in
{
  f1ux = loadImages f1ux;
  gesso2 = loadImages gesso2;
}
