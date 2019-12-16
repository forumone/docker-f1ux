# How to build PHP from this file:
#   nix-build php.nix -A \"7.1\"
#
# The escapes are needed since "7.1" doesn't follow Nix's normal rules for attribute names
let
  util = import ./util.nix;

  versions = [
    # bleah, oniguruma
    # { version = "7.4.0"; sha256 = "bf206be96a39e643180013df39ddcd0493966692a2422c4b7d3355b6a15a01c0"; }

    # The sha256 digest here is for the .tar.bz2 files of the PHP source distribution
    { version = "7.3.12"; sha256 = "d317b029f991410578cc38ba4b76c9f764ec29c67e7124e1fec57bceb3ad8c39"; }
    { version = "7.2.25"; sha256 = "7cb336b1ed0f9d87f46bbcb7b3437ee252d0d5060c0fb1a985adb6cbc73a6b9e"; }
    { version = "7.1.33"; sha256 = "95a5e5f2e2b79b376b737a82d9682c91891e60289fa24183463a2aca158f4f4b"; }

    # libxml2 detection broken for some reason
    # { version = "7.0.33"; sha256 = "4933ea74298a1ba046b0246fe3771415c84dfb878396201b56cb5333abe86f07"; }
  ];

  mkPhpDerivation =
    { name, version, sha256 }:
    let
      # Import nixpkgs and the standard build environment
      pkgs = import <nixpkgs> {};

      # This derivation uses static links to reduce the build output's size
      inherit (pkgs.pkgsStatic) stdenv lib fetchurl;
      inherit (pkgs.pkgsStatic) pkgconfig libxml2 bzip2 oniguruma openssl;
      inherit (pkgs) zlib;

    in
    stdenv.mkDerivation {
      name = "php-${name}";
      src = fetchurl {
        url = "https://www.php.net/distributions/php-${version}.tar.bz2";
        inherit sha256;
      };

      enableParallelBuilding = true;
      static = true;

      nativeBuildInputs = with (pkgs.pkgsStatic); [
        pkgconfig
        autoconf
        libxml2
        (lib.getDev libxml2)
      ];

      CFLAGS = "-I${libxml2.dev}/include";
      LDFLAGS = "-L${libxml2.out}/lib";

      # 1. Omit the "@CONFIGURE_*@" flags (these are output by php -i) in order to further
      #    reduce this derivation's output size
      # 2. Manually add libxml2 to PKG_CONFIG_PATH
      # 3. Regenerate ./configure
      preConfigure = ''
        for offender in main/build-defs.h.in scripts/php-config.in; do
          substituteInPlace $offender \
            --replace '@CONFIGURE_COMMAND@' '(omitted)' \
            --replace '@CONFIGURE_OPTIONS@' ""
        done

        addPkgConfigPath ${lib.getDev libxml2}
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
        "--with-filter=static"
        "--enable-libxml"

        # These are needed by Composer
        "--enable-phar=static"
        "--enable-mbstring=static"
        "--enable-json=static"
      ];

      # Move php-config and php-ize to the $dev output
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
