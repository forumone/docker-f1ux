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
  # [1]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/top-level/php-packages.nix [2]:
  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/php-packages/composer/default.nix
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
  php74 = generic { version = "7.4.1"; sha256 = "6b1ca0f0b83aa2103f1e454739665e1b2802b90b3137fc79ccaa8c242ae48e4e"; };
  composer74 = composer php74;

  php73 = generic { version = "7.3.13"; sha256 = "5c7b89062814f3c3953d1518f63ed463fd452929e3a37110af4170c5d23267bc"; };
  composer73 = composer php73;

  php72 = generic { version = "7.2.26"; sha256 = "f36d86eecf57ff919d6f67b064e1f41993f62e3991ea4796038d8d99c74e847b"; };
  composer72 = composer php72;

  php71 = generic { version = "7.1.33"; sha256 = "95a5e5f2e2b79b376b737a82d9682c91891e60289fa24183463a2aca158f4f4b"; };
  composer71 = composer php71;

  php70 = generic { version = "7.0.33"; sha256 = "4933ea74298a1ba046b0246fe3771415c84dfb878396201b56cb5333abe86f07"; };
  composer70 = composer php70;

  php56 = generic { version = "5.6.40"; sha256 = "ffd025d34623553ab2f7fd8fb21d0c9e6f9fa30dc565ca03a1d7b763023fba00"; };
  composer56 = composer php56;

  inherit removeMemoryLimit;
}
