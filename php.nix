{
  # Nix library elements
  stdenv, lib, fetchurl, newScope

  # Builders
, writeTextFile, runCommand, makeWrapper

  # Build tools
, pkgconfig, autoconf

  # Build dependencies
, libxml2, libzip, oniguruma, openssl, openssl_1_0_2, zlib

  # Composer and friends
, phpPackages
}:
let
  # Usage:
  # * version: Full PHP version (e.g., 7.1.33)
  # * sha256: SHA256 checksum of the .tar.bz2 source archive
  generic =
    { version, sha256 }:
    let
      libxmlFlag =
        if lib.versionAtLeast version "7.1"
        then "--enable-libxml=static"
        else "--with-libxml-dir=${libxml2.dev}";

      # Use older OpenSSL for 5.6 - it doesn't appear to be compatible with 1.1.
      sslpkg =
        if lib.versionAtLeast version "7.0"
        then openssl
        else openssl_1_0_2;
    in
    stdenv.mkDerivation {
      pname = "php";
      inherit version;

      src = fetchurl {
        url = "https://www.php.net/distributions/php-${version}.tar.bz2";
        inherit sha256;
      };

      enableParallelBuilding = true;

      buildInputs = [
        libxml2
        libzip
        oniguruma
        sslpkg
        zlib
      ];

      nativeBuildInputs = [
        pkgconfig
        autoconf
      ];

      # 1. Omit the "@CONFIGURE_*@" flags (these are output by php -i) in order to further
      #    reduce this derivation's output size
      # 2. Manually add libxml2's utilities to $PATH
      # 3. Regenerate ./configure
      preConfigure = ''
        for offender in main/build-defs.h.in scripts/php-config.in; do
          substituteInPlace $offender \
            --replace '@CONFIGURE_COMMAND@' '(omitted)' \
            --replace '@CONFIGURE_OPTIONS@' ""
        done

        addToSearchPath PATH ${lib.getDev libxml2}/bin

        configureFlags+=(--includedir=$dev/include)

        ./buildconf --force
      '';

      configureFlags = [
        # Only build static extensions
        "--disable-shared"

        # Don't build unneeded SAPIs
        "--disable-cgi"
        "--disable-phpdbg"

        # Don't enable default extensions
        "--disable-all"

        # Enable filter and libxml
        "--enable-filter=static"
        libxmlFlag

        # These are needed by Composer
        "--enable-phar=static"
        "--enable-mbstring=static"
        "--enable-json=static"
        "--with-openssl"

        # Pattern Lab
        "--enable-tokenizer"
        "--enable-hash=static"
        "--enable-ctype=static"
        "--enable-zip=static"
        "--with-zlib-dir=${zlib.dev}"

        "PKG_CONFIG=${pkgconfig}/bin/${pkgconfig.targetPrefix}pkg-config"
      ];

      passthru = {
        dockerKey = "php-${lib.versions.majorMinor version}";
      };

      # Move php-config and php-ize to the $dev output (see below)
      postInstall = ''
        mkdir -p $dev/bin
        for tool in phpize php-config; do
          mv $out/bin/$tool $dev/bin/$tool
        done
      '';

      # Create a separate $dev output to avoid pulling them in by default (we don't build
      # any extensions in a Gesso image)
      outputs = [ "out" "dev" ];
    };

  # Create a new callPackage function specific to this PHP version. This is the idiom used
  # by upstream nixpkgs in order to create PHP-specific derivations (see, e.g., [1]). By
  # adopting this idiom ourselves, we can use the Composer derivation (the angle brackets
  # are a path in nixpkgs root, arriving at [2]) directly, replacing nixpkgs' PHP with the
  # one custom-built in this file.
  #
  # [1]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/top-level/php-packages.nix
  # [2]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/php-packages/composer/default.nix
  composer = php:
    let
      mkDerivation = { pname, ... }@args:
        stdenv.mkDerivation (args // { pname = "php-${pname}"; });

      callPackage = newScope {
        inherit mkDerivation php;
      };
    in
    callPackage <nixpkgs/pkgs/development/php-packages/composer> {};

  # Creates a config file to remove the PHP memory limit
  memoryLimitConfig = writeTextFile {
    name = "cli.ini";
    text = ''
      memory_limit = -1
    '';
  };

  # Wraps a PHP derivation to add the "-c" flag (path to a config file) that references
  # the above memoryLimitConfig derivation.
  removeMemoryLimit = php: runCommand "php-cli-${php.version}"
    { buildInputs = [ makeWrapper ]; }
    ''
      mkdir -p $out
      makeWrapper "${php}/bin/php" "$out/bin/php" \
        --argv0 php \
        --add-flags "-c ${memoryLimitConfig}"
    '';
in
rec {
  # NB. sha256 is of the .tar.bz2 archive (see php.net/downloads and php.net/releases)
  php82 = generic { version = "8.2.8"; sha256 = "995ed4009c7917c962d31837a1a3658f36d4af4f357b673c97ffdbe6403f8517"; };
  composer82 = composer php82;

  php81 = generic { version = "8.1.21"; sha256 = "6ea49e8335d632177f56b507160aa151c7b020185789a9c14859fce5d4a0776d"; };
  composer81 = composer php81;

  php80 = generic { version = "8.0.29"; sha256 = "4801a1f0e17170286723ab54acd045ac78a9656021d56f104a64543eec922e12"; };
  composer80 = composer php80;

  php74 = generic { version = "7.4.33"; sha256 = "4e8117458fe5a475bf203128726b71bcbba61c42ad463dffadee5667a198a98a"; };
  composer74 = composer php74;

  inherit removeMemoryLimit;
}
