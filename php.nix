# How to build PHP from this file:
#   nix-build php.nix -A \"7.1\"
#
# The escapes are needed since "7.1" doesn't follow Nix's normal rules for attribute names
let
  util = import ./util.nix;

  versions = [
    # The sha256 digest here is for the .tar.bz2 files of the PHP source distribution
    { version = "7.4.1"; sha256 = "6b1ca0f0b83aa2103f1e454739665e1b2802b90b3137fc79ccaa8c242ae48e4e"; }
    { version = "7.3.13"; sha256 = "5c7b89062814f3c3953d1518f63ed463fd452929e3a37110af4170c5d23267bc"; }
    { version = "7.2.26"; sha256 = "f36d86eecf57ff919d6f67b064e1f41993f62e3991ea4796038d8d99c74e847b"; }
    { version = "7.1.33"; sha256 = "95a5e5f2e2b79b376b737a82d9682c91891e60289fa24183463a2aca158f4f4b"; }
    { version = "7.0.33"; sha256 = "4933ea74298a1ba046b0246fe3771415c84dfb878396201b56cb5333abe86f07"; }
    { version = "5.6.40"; sha256 = "ffd025d34623553ab2f7fd8fb21d0c9e6f9fa30dc565ca03a1d7b763023fba00"; }
  ];

  mkPhpDerivation =
    { name, version, sha256 }:
    let
      # Import nixpkgs and the standard build environment
      pkgs = import <nixpkgs> {};

      inherit (pkgs) stdenv lib fetchurl;
      inherit (pkgs) pkgconfig libxml2 zlib;

      libxmlFlag =
        if lib.versionAtLeast version "7.1"
        then "--enable-libxml=static"
        else "--with-libxml-dir=${libxml2.dev}";

      # 5.6 needs a really old OpenSSL version - but let's keep it limited to just that.
      openssl =
        if lib.versionAtLeast version "7.0"
        then pkgs.openssl
        else pkgs.openssl_1_0_2;
    in
    stdenv.mkDerivation {
      pname = "php";
      inherit version;

      src = fetchurl {
        url = "https://www.php.net/distributions/php-${version}.tar.bz2";
        inherit sha256;
      };

      enableParallelBuilding = true;

      buildInputs = with pkgs; [
        libxml2
        libzip
        oniguruma
        openssl
        zlib
      ];

      nativeBuildInputs = with pkgs; [
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
      ];

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
in
util.mkMatrix {
  key = name: builtins.head (builtins.split "\\.[0-9]+$" name);
  versions = versions;
  mkDerivation = mkPhpDerivation;
}
