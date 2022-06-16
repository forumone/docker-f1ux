{
  stdenv, fetchurl, lib

  # Build dependencies
, python2
, python3

  # Grunt
, nodejs, nodePackages
}:
let
  # Use specific configure flags because stdenv's defaults confuse the custom
  # configure script.
  configureFlags = [
    # Build to the $out path
    "--prefix" "$out"

    # Don't generate v8 snapshots
    "--without-snapshot"
  ];

  # Grabs the node major version from a string like v10.1.0 - we can't use `lib.versions.major` directly
  # because it only picks up the "v" due to parsing shenanigans.
  major = version:
    let
      # slice = version[1..]
      slice =
        builtins.substring
          1
          (builtins.stringLength version)
          version;
    in
    "v${lib.versions.major slice}";

  # Usage:
  # * version: Full Node.js version (e.g., v4.9.1)
  # * sha256: SHA256 checksum of the .tar.xz source archive
  # * python: Python derivation (version 2 or 3, used to allow building node v16)
  generic =
    { version, sha256, python ? python2 }:
    stdenv.mkDerivation {
      pname = "node";
      inherit version;

      src = fetchurl {
        url = "https://nodejs.org/dist/${version}/node-${version}.tar.xz";
        sha256 = sha256;
      };

      enableParallelBuilding = true;

      nativeBuildInputs = [python];

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

        python $configure ${builtins.concatStringsSep " " configureFlags}
      '';

      # Repatch shebang lines to point to the build Node
      postInstall = ''
        HOST_PATH=$out/bin:$HOST_PATH patchShebangs --host $out
      '';

      # Move dev- and doc-related artifacts to separate outputs, which we don't copy into
      # the Gesso image.
      outputs = ["out" "dev" "doc"];

      passthru = {
        dockerKey = "node-${major version}";
      };
    };

  # Creates a grunt-cli derivation applicable to this node package.
  grunt = node:
    let
      # Replaces grunt-cli's nodejs with our own (see below)
      replaceNode = builtins.map (pkg: if pkg == nodejs then node else pkg);
    in
      nodePackages.grunt-cli.overrideDerivation (old: {
        # Create a "patch" that replaces node in the derivation's inputs. The result of this is
        # identical to nixpkgs' grunt-cli, except that it is now linked to our custom Node
        # instead of nixpkgs' grunt
        buildInputs = replaceNode old.buildInputs;
      });

in rec {
  # The sha256 digest here is for the .tar.xz of the Node sources
  # node16 = generic { version = "v16.15.0"; sha256 = "a0f812efc43f78321eca08957960a48f5e6bf97004d5058c8dd3b03c646ea4f7"; python = python3; };
  # grunt16 = grunt node16;

  node14 = generic { version = "v14.19.3"; sha256 = "5cf45b1f1aca77523acf36240c1d53a999279070a7711eabf23346f88b0cc994"; };
  grunt14 = grunt node14;

  node12 = generic { version = "v12.22.12"; sha256 = "bc42b7f8495b9bfc7f7850dd180bb02a5bdf139cc232b8c6f02a6967e20714f2"; };
  grunt12 = grunt node12;

  node10 = generic { version = "v10.24.1"; sha256 = "d72fc2c244603b4668da94081dc4d6067d467fdfa026e06a274012f16600480c"; };
  grunt10 = grunt node10;

  node8 = generic { version = "v8.17.0"; sha256 = "5b0d96db482b273f0324c299ead86ecfbc5d033516e5fc37c92cfccb933ef6ff"; };
  grunt8 = grunt node8;

  node6 = generic { version = "v6.17.1"; sha256 = "6f6dc9624656a008513b7608bfc105dd92ceea5d7b4516edeca7e6b19d2edd94"; };
  grunt6 = grunt node6;

  node4 = generic { version = "v4.9.1"; sha256 = "d7d1232f948391699c6e98780ac90bdf5889902d639bad41561ac29f03dad401"; };
  grunt4 = grunt node4;
}
