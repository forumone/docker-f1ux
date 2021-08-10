# Entrypoint for derivations consuming the overlay (see default.nix).
let
  nixpkgs = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/32fc8b9134c5fd56851ba1845f04d17484ea7170.tar.gz";
in
import nixpkgs {
  overlays = [(import ./overlay.nix)];
}
