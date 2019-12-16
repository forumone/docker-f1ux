# How to build Ruby from this file:
#   nix-build ruby.nix -A \"2.3\"
#
# The escapes are needed since "2.3" doesn't follow Nix's normal rules for attribute names
let
  util = import ./util.nix;

  # List of versions mapped to the SHA256 checksum of the source tarball (.tar.gz)
  versions = [
    # Versions later than 2.3 fail to build looking for "ruby/ruby.h". This could be issues
    # due to Ruby thinking it's being cross-compiled, but just having 2.3 will suffice.
    # { version = "2.6.5"; sha256 = "66976b716ecc1fd34f9b7c3c2b07bbd37631815377a2e3e85a5b194cfdcbed7d"; }
    # { version = "2.5.7"; sha256 = "0b2d0d5e3451b6ab454f81b1bfca007407c0548dea403f1eba2e429da4add6d4"; }
    # { version = "2.4.9"; sha256 = "f99b6b5e3aa53d579a49eb719dd0d3834d59124159a6d4351d1e039156b1c6ae"; }

    { version = "2.3.8"; sha256 = "b5016d61440e939045d4e22979e04708ed6c8e1c52e7edb2553cf40b73c59abf"; }
  ];

  # Function to build a single Ruby
  mkRubyDerivation =
    { name, version, sha256 }:
    let
      # Import nixpkgs and the standard build environment
      pkgs = import <nixpkgs> {};
      inherit (pkgs) stdenv;

      src = pkgs.fetchurl {
        url = "https://cache.ruby-lang.org/pub/ruby/${name}/ruby-${version}.tar.gz";
        inherit sha256;
      };

      # Ruby's configure has trouble with static extensions, so we just point it to these
      # build paths directly.
      # We only use zlib and openssl since they're needed for `gem install` and friends
      environment = with (pkgs.pkgsStatic); {
        CFLAGS = "-I${zlib.dev}/include -I${openssl.dev}/include";
        LDFLAGS = "-L${zlib.static}/lib -L${openssl.out}/lib";
      };

      # Ruby gems are packaged by X.Y.0 versions, no matter what the actual patch-level
      # version is, so we can just statically predict it here
      versionKey = "${name}.0";
    in
    stdenv.mkDerivation {
      name = "ruby-${name}";
      inherit src;

      # Passes -j$(nproc) to make during the build phase
      enableParallelBuilding = true;

      CFLAGS = environment.CFLAGS;
      LDFLAGS = environment.LDFLAGS;

      configureFlags = [
        # Don't use GCC for the JIT
        "--disable-jit-support"

        # Don't build docs (reduces derivation size)
        "--disable-install-doc"

        # Only use static compilation
        "--disable-shared"
        "--enable-static"
      ];

      # In addition to the regular install location, we have a separate path to copy the
      # documentation to
      outputs = ["out" "doc"];

      # Discard the -test- extension because it causes some weird issues during the build
      preConfigure = ''
        rm -rf ext/-test-
      '';

      # Ask Ruby to statically link all available extensions
      postConfigure = ''
        sed -i -e '2,$s/^#//' ext/Setup
      '';

      # 1. Copy docs to the doc output
      # 2.
      postInstall = ''
        mkdir -p $doc/share
        mv $out/share $doc/share

        PATH=$out/bin:$PATH patchShebangs --host $out
      '';

      # Metadata needed for our Bundler gem build
      passthru = {
        gemPath = "lib/ruby/gems/${versionKey}/gems";
      };
    };
in
util.mkMatrix {
  key = name: builtins.head (builtins.split "\\.[0-9]+$" name);
  versions = versions;
  mkDerivation = mkRubyDerivation;
}
