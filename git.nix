let
  pkgs = import <nixpkgs> {};
in
# Customize nixpkgs' git derivation to minimize Docker footprint
pkgs.git.override {
  perlSupport = false;
  pythonSupport = false;
  withManual = false;
}
