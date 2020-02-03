# Packages Medium's PhantomJS as a derivation. We go this route instead of using nixpkgs'
# phantomjs2 due to it requiring qtwebkit, which results in our images including a large
# amount of the desktop stack
#
# This precompiled binary has a much smaller closure size and is thus much more amenable
# to our attempts to keep image sizes down.
{
  stdenv, fetchurl

  # This hook will force resolution of the dynamic libraries needed by phantomjs
, autoPatchelfHook

  # Libraries needed by phantomjs as determined by ldd
  # (NB. gcc-unwrapped gives us access to libstdc++)
, expat, fontconfig, freetype, gcc-unwrapped, libpng, libuuid, zlib

, lib
}:
let
  generic =
    # Parameters:
    # - version: The PhantonJS version
    # - sha256: The checksum of the release tarball (linux-x86_64)
    # - release: The GitHub release in case it differs from the related PhantomJS version
    { version, sha256, release ? version }:
    stdenv.mkDerivation {
      pname = "phantomjs-prebuilt";
      inherit version;

      src = fetchurl {
        url = "https://github.com/Medium/phantomjs/releases/download/v${release}/phantomjs-${version}-linux-x86_64.tar.bz2";
        inherit sha256;
      };

      buildInputs = [
        autoPatchelfHook
        expat
        fontconfig
        freetype
        gcc-unwrapped.lib
        libpng
        libuuid
        zlib
      ];

      dontBuild = true;

      outputs = [ "out" "doc" ];

      installPhase = ''
        mkdir -p $out
        mv bin $out/bin

        mkdir -p $doc
        cp -R . $doc
      '';
    };
in
{
  phantomjs-prebuilt = generic {
    version = "2.1.1";
    sha256 = "0bqd8r97inh5f682m3cykg76s7bwjkqirxn9hhd5zr5fyi5rmpc6";
  };

  phantomjs-prebuilt_19 = generic {
    version = "1.9.8";
    release = "1.9.19";
    sha256 = "0fhnqxxsxhy125fmif1lwgnlhfx908spy7fx9mng4w72320n5nd1";
  };
}
