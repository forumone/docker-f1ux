let
  util = import ./util.nix;

  versions = [
    # The sha256 digest here is for the .tar.xz of the Node sources
    { version = "v12.13.1"; sha256 = "349e3a739cc26bb0975c0ada12b11933568ecbea459297fe8ae0a2acc351b192"; }
    { version = "v10.17.0"; sha256 = "412667d76bd5273c07cb69c215998109fd5bb35c874654f93e6a0132d666c58e"; }
    { version = "v8.16.2"; sha256 = "8c16b500ad74c1b1bde099996c287eeed5a4b2ab0efdf5d94d1d683cc2654ec3"; }
    { version = "v6.17.1"; sha256 = "6f6dc9624656a008513b7608bfc105dd92ceea5d7b4516edeca7e6b19d2edd94"; }
    { version = "v4.9.1"; sha256 = "d7d1232f948391699c6e98780ac90bdf5889902d639bad41561ac29f03dad401"; }
  ];

  mkNodeDerivation =
    { name, version, sha256 }:
    let
      # Import nixpkgs and the standard environment
      pkgs = import <nixpkgs> {};

      inherit (pkgs) stdenv fetchurl python2;

      # Use specific configure flags because stdenv's defaults confuse the custom
      # configure script.
      configureFlags = [
        # Build to the $out path
        "--prefix" "$out"

        # Don't generate v8 snapshots
        "--without-snapshot"
      ];
    in
    stdenv.mkDerivation {
      pname = "node";
      inherit version;

      src = fetchurl {
        url = "https://nodejs.org/dist/${version}/node-${version}.tar.xz";
        sha256 = sha256;
      };

      enableParallelBuilding = true;

      nativeBuildInputs = [python2];

      # Point build scripts to the exact Nix store paths rather than /usr/bin/env
      postPatch = ''
        patchShebangs .
      '';

      # Not all node versions have a configure.py, so we have to vary which script we call
      # (If the source has both, then ./configure is a shell script that uses `which` to
      # sniff out the path to python, but we've injected it directly via nativeBuildInputs)
      configurePhase = ''
        if test -f configure.py; then
          configure=configure.py
        else
          configure=configure
        fi

        python2 $configure ${builtins.concatStringsSep " " configureFlags}
      '';

      # Repatch shebang lines to point to the build Node
      postInstall = ''
        HOST_PATH=$out/bin:$HOST_PATH patchShebangs --host $out
      '';

      # Move dev- and doc-related artifacts to separate outputs, which we don't copy into
      # the Gesso image.
      outputs = ["out" "dev" "doc"];
    };
in
util.mkMatrix {
  key = name: builtins.head (builtins.split "\\." name);
  versions = versions;
  mkDerivation = mkNodeDerivation;
}
