{
  stdenv, fetchurl, lib

, openssl_1_0_2, zlib
}:
let
  generic =
    { version, sha256 }:
    let
      versionKey = lib.versions.majorMinor version;
    in
    stdenv.mkDerivation {
      pname = "ruby";
      inherit version;

      src = fetchurl {
        url = "https://cache.ruby-lang.org/pub/ruby/${versionKey}/ruby-${version}.tar.gz";
        inherit sha256;
      };

      # Passes -j$(nproc) to make during the build phase
      enableParallelBuilding = true;

      buildInputs = [
        openssl_1_0_2
        zlib
      ];

      configureFlags = [
        # Don't use GCC for the JIT
        "--disable-jit-support"

        # Don't build docs (reduces derivation size)
        "--disable-install-doc"
      ];

      # In addition to the regular install location, we have a separate path to copy the
      # documentation to
      outputs = ["out" "doc"];

      # Discard the -test- extension because it causes some weird issues during the build
      preConfigure = ''
        rm -rf ext/-test-
      '';

      # Copy docs to the doc output
      postInstall = ''
        mkdir -p $doc/share
        mv $out/share $doc/share

        PATH=$out/bin:$PATH patchShebangs --host $out
      '';

      # Metadata needed for our Bundler gem build
      passthru = {
        gemPath = "lib/ruby/gems/${versionKey}/gems";

        dockerKey = "ruby-${versionKey}";
      };
    };
in
generic {
  version = "2.3.8";
  sha256 = "b5016d61440e939045d4e22979e04708ed6c8e1c52e7edb2553cf40b73c59abf";
}
