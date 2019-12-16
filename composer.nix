# Function to install Composer using the custom-compiled PHP
{ php }:
let
  pkgs = import <nixpkgs> {};
  inherit (pkgs.pkgsStatic) stdenv fetchurl;
in
stdenv.mkDerivation {
  name = "composer";
  src = fetchurl {
    url = "https://getcomposer.org/download/1.9.1/composer.phar";
    sha256 = "1f210b9037fcf82670d75892dfc44400f13fe9ada7af9e787f93e50e3b764111";
  };

  dontUnpack = true;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  # Nothing to build
  buildPhase = ''
    true
  '';

  # We create a wrapper for composer instead of rewrite the .phar - this lets us preserve
  # the checksum of composer.phar.
  installPhase = ''
    install -D $src $out/libexec/composer.phar

    mkdir -p $out/bin
    makeWrapper ${php}/bin/php $out/bin/composer \
      --add-flags "$out/libexec/composer.phar"
  '';
}
