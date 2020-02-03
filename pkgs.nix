# Entrypoint for derivations consuming the overlay (see default.nix).
import <nixpkgs> {
  overlays = [(import ./overlay.nix)];
}
