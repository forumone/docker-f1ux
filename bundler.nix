# Function to install Bundler 2 using the custom Ruby install
{ ruby }:
let
  pkgs = import <nixpkgs> {};

  gemName = "bundler";
  version = "2.0.2";
  sha256 = "4c2ae1fce8a072b832ac7188f1e530a7cff8f0a69d8a9621b32d1407db00a2d0";
in
pkgs.buildRubyGem {
  inherit ruby;

  # Metadata for this gem derivation
  name = "${gemName}-${version}";
  inherit gemName;
  inherit version;

  # We get weird build failures without these
  GEM_PATH = "";
  dontInstallManpages = true;
  dontPatchShebangs = true;

  nativeBuildInputs = [ ruby ];
  source.sha256 = sha256;

  # "borrowed" from nixpkgs' bundler derivation
  postFixup = ''
    sed -i -e "s/activate_bin_path/bin_path/g" $out/bin/bundle
  '';
}
