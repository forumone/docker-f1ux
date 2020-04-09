# This file hosts a pair of shell scripts needed to adjust library references in binaries
# in order to make them play nice with the Nix model.
#
# What does that mean? Here's an attempt to explain it:
#
# First, dynamic libraries in Linux are handled as string references to a shared object
# (.so) file. We can use tools like `ldd' to see what libraries a binary needs. Since
# this script is largely intended to support PhantomJS, we'll be using that as an example.
#
# You can follow along by downloading PhantomJS here: https://github.com/Medium/phantomjs/releases/tag/v2.1.1
#
# First, we'll use `ldd` on my Ubuntu laptop. Here is what `ldd` prints:
#
# $ ldd bin/phantomjs
#        linux-vdso.so.1 (0x00007ffc9f8d5000)
#        libz.so.1 => /lib/x86_64-linux-gnu/libz.so.1 (0x00007f8bc1b45000)
#        libfontconfig.so.1 => /usr/lib/x86_64-linux-gnu/libfontconfig.so.1 (0x00007f8bc1aff000)
#        libfreetype.so.6 => /usr/lib/x86_64-linux-gnu/libfreetype.so.6 (0x00007f8bc1a44000)
#        libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x00007f8bc1a3e000)
#        librt.so.1 => /lib/x86_64-linux-gnu/librt.so.1 (0x00007f8bc1a33000)
#        libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (0x00007f8bc1a10000)
#        libstdc++.so.6 => /usr/lib/x86_64-linux-gnu/libstdc++.so.6 (0x00007f8bc1820000)
#        libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x00007f8bc16d1000)
#        libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1 (0x00007f8bc16b7000)
#        libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f8bc14c6000)
#        /lib64/ld-linux-x86-64.so.2 (0x00007f8bc1b83000)
#        libexpat.so.1 => /lib/x86_64-linux-gnu/libexpat.so.1 (0x00007f8bc1498000)
#        libuuid.so.1 => /lib/x86_64-linux-gnu/libuuid.so.1 (0x00007f8bc148f000)
#        libpng16.so.16 => /usr/lib/x86_64-linux-gnu/libpng16.so.16 (0x00007f8bc1455000)
#
# Next, we'll use Nix's `ldd`. Unlike my system `ldd`, it won't use the default search
# path:
#
# $  nix-shell -p glibc.bin --run 'ldd bin/phantomjs'
#        linux-vdso.so.1 (0x00007f51e3528000)
#        libz.so.1 => not found
#        libfontconfig.so.1 => not found
#        libfreetype.so.6 => not found
#        libdl.so.2 => /nix/store/9rabxvqbv0vgjmydiv59wkz768b5fmbc-glibc-2.30/lib/libdl.so.2 (0x00007f51e351e000)
#        librt.so.1 => /nix/store/9rabxvqbv0vgjmydiv59wkz768b5fmbc-glibc-2.30/lib/librt.so.1 (0x00007f51e3514000)
#        libpthread.so.0 => /nix/store/9rabxvqbv0vgjmydiv59wkz768b5fmbc-glibc-2.30/lib/libpthread.so.0 (0x00007f51e34f1000)
#        libstdc++.so.6 => not found
#        libm.so.6 => /nix/store/9rabxvqbv0vgjmydiv59wkz768b5fmbc-glibc-2.30/lib/libm.so.6 (0x00007f51e33b1000)
#        libgcc_s.so.1 => /nix/store/9rabxvqbv0vgjmydiv59wkz768b5fmbc-glibc-2.30/lib/libgcc_s.so.1 (0x00007f51e3397000)
#        libc.so.6 => /nix/store/9rabxvqbv0vgjmydiv59wkz768b5fmbc-glibc-2.30/lib/libc.so.6 (0x00007f51e31d8000)
#        /lib64/ld-linux-x86-64.so.2 => /nix/store/9rabxvqbv0vgjmydiv59wkz768b5fmbc-glibc-2.30/lib64/ld-linux-x86-64.so.2 (0x00007f51e3529000)
#
# Uh oh. Even though I had all the libraries, ldd refused to find them. This is the core
# of the problem that we have with allowing npm to download binaries that are precompiled
# for Linux: on all other systems, they will work as long as the packages are installed,
# but Nix relies on a model where a program's dependencies are explicit, not implicit.
#
# How does this work? This relies on a feature of Linux executables called RPATH. This is a
# colon-delimited string that tells the loader where else to search for libraries in addition
# to the system default. Since Nix doesn't have a system-wide default, this means that unless
# a program has an RPATH, it won't work.
#
# When we build a binary using Nix, we get this for free. The loader (ld) is wrapped by
# nix-build to create the RPATH for us. However, `npm install` doesn't run in a nix-build,
# so we have to manually adjust anything it downloads after the fact.
#
# Luckily, there is a tool that performs exactly this job: patchelf (https://github.com/NixOS/patchelf).
# We make use of four of its options:
#
# 1. --print-needed. This is the flag that asks patchelf to determine what library files
#    a program needs.
#
#    In the case of PhantomJS, we get this output:
#
#    $ nix-shell -p patchelf --run 'patchelf --print-needed bin/phantomjs'
#    libz.so.1
#    libfontconfig.so.1
#    libfreetype.so.6
#    libdl.so.2
#    librt.so.1
#    libpthread.so.0
#    libstdc++.so.6
#    libm.so.6
#    libgcc_s.so.1
#    libc.so.6
#    ld-linux-x86-64.so.2
#
# 2. --set-interpreter. The interpreter (known as ld-linux-x86-64.so.2 in the preceding
#    example) is the dynamic loader - the part of the system that opens up other .so files
#    and exposes them to the program (more reading: https://linux.die.net/man/8/ld-linux).
#
#    As with all things Nix, ld-linux is in the Nix store and has a unique path. We use
#    this flag to update the program's interpreter to this path.
#
# 3. --set-rpath. This is where the "real" magic happens. The patch-binary script (see below)
#    collects the names of all of the libraries we have chosen to expose to npm-downloaded
#    binaries (i.e., PhantomJS) and manually collects the RPATH for them.
#
#    Using the phantomjs example above, we can see that it needs a copy of libfreetype.so.6.
#    We can ask Nix where the freetype library is installed in the Nix store:
#
#    $ nix repl '<nixpkgs>'
#    Welcome to Nix version 2.3.2. Type :? for help.
#
#    nix-repl> "${lib.getLib freetype}"
#    "/nix/store/xrq4n5k4l02bffxkm1af3c5v4ccfxilc-freetype-2.10.1"
#
#    When we inspect that path, we see the following contents in its lib/ subdirectory:
#
#    $ ls /nix/store/xrq4n5k4l02bffxkm1af3c5v4ccfxilc-freetype-2.10.1/lib
#    libfreetype.a  libfreetype.la  libfreetype.so  libfreetype.so.6  libfreetype.so.6.17.1
#
#    The patch-binary script will see all of the '.so' and '.so.*' files and store the
#    following array associations:
#
#    declare -A dependencyCache=(
#      [libfreetype.so]=/nix/store/xrq4n5k4l02bffxkm1af3c5v4ccfxilc-freetype-2.10.1/lib
#      [libfreetype.so.6]=/nix/store/xrq4n5k4l02bffxkm1af3c5v4ccfxilc-freetype-2.10.1/lib
#      [libfreetype.so.6.17.1]=/nix/store/xrq4n5k4l02bffxkm1af3c5v4ccfxilc-freetype-2.10.1/lib
#    )
#
#    By looping through the output of --print-needed, we can perform a lookup against this
#    array and resolve any library references. The resulting list of directories then
#    forms the program's RPATH, and we will be able to resolve the list.
#
#    If I use patchelf to set the RPATH to include the freetype directory, here's what
#    happens:
#
#    $ nix-shell -p patchelf --run 'patchelf --set-rpath /nix/store/xrq4n5k4l02bffxkm1af3c5v4ccfxilc-freetype-2.10.1/lib bin/phantomjs'
#    $ nix-shell -p glibc.bin --run 'ldd bin/phantomjs'
#            linux-vdso.so.1 (0x00007ffcd23ea000)
#            libz.so.1 => not found
#            libfontconfig.so.1 => not found
#            libfreetype.so.6 => /nix/store/xrq4n5k4l02bffxkm1af3c5v4ccfxilc-freetype-2.10.1/lib/libfreetype.so.6 (0x00007f7162c49000)
#            libdl.so.2 => /nix/store/9rabxvqbv0vgjmydiv59wkz768b5fmbc-glibc-2.30/lib/libdl.so.2 (0x00007f7162c44000)
#            librt.so.1 => /nix/store/9rabxvqbv0vgjmydiv59wkz768b5fmbc-glibc-2.30/lib/librt.so.1 (0x00007f7162c3a000)
#            libpthread.so.0 => /nix/store/9rabxvqbv0vgjmydiv59wkz768b5fmbc-glibc-2.30/lib/libpthread.so.0 (0x00007f7162c17000)
#            libstdc++.so.6 => not found
#            libm.so.6 => /nix/store/9rabxvqbv0vgjmydiv59wkz768b5fmbc-glibc-2.30/lib/libm.so.6 (0x00007f7162ad7000)
#            libgcc_s.so.1 => /nix/store/9rabxvqbv0vgjmydiv59wkz768b5fmbc-glibc-2.30/lib/libgcc_s.so.1 (0x00007f7162abd000)
#            libc.so.6 => /nix/store/9rabxvqbv0vgjmydiv59wkz768b5fmbc-glibc-2.30/lib/libc.so.6 (0x00007f71628fe000)
#            /lib64/ld-linux-x86-64.so.2 => /nix/store/9rabxvqbv0vgjmydiv59wkz768b5fmbc-glibc-2.30/lib64/ld-linux-x86-64.so.2 (0x00007f7162d0a000)
#            libbz2.so.1 => /nix/store/q8nbmrhblmzfhmwqkk65v836j6cxgpvf-bzip2-1.0.6.0.1/lib/libbz2.so.1 (0x00007f71628eb000)
#            libpng16.so.16 => /nix/store/00zb0xn08zvp7bnf2nvj8zmbaziwvns7-libpng-apng-1.6.37/lib/libpng16.so.16 (0x00007f71628b0000)
#            libz.so.1 => /nix/store/fgi7xhmh3hs2v5pzq2k8r4kw22h9yy9g-zlib-1.2.11/lib/libz.so.1 (0x00007f7162893000)
#
#    Notice that libfreetype.so.6 has now been resolved by ldd to the correct path.
#
# 4. --shrink-rpath. It's possible that we resolved multiple libraries to the same location,
#    especially when we're linking against things that are provided by glibc or the gcc
#    runtime libraries. Instead of managing our own deduplication logic, we allow patchelf
#    to use its knowledge of the linker and file formats to perform this operation for us.
#
# The patch-binary script acts as a driver of sorts for patchelf. It collects the depdencies
# and loops over them to resolve references. We've included a list of libraries to get
# started: most of them are related to PhantomJS, but we've also included libpng12 for
# pngquant, which is used by at least one project for image optimization.
#
# The resolve-all-libraries script is a driver for patch-binary. What it does is loop
# over the directories the user has provided and run patch-binary on all of the executables
# it finds in a single pass. This way, patch-binary can re-use the dependency cache it built
# instead of generating it multiple times in a single run.
{
  # Nixpkgs lib
  lib

  # Utilities (mostly 'find')
, busybox

  # These libraries are needed by phantomjs for resolution
, expat, fontconfig, freetype, gcc-unwrapped, libpng, libuuid, zlib, glibc
  # Some versions of pngquant need this
, libpng12

  # Patchelf is used to resolve library paths
, patchelf

  # Builders for shell scripts
, writeShellScript
, writeShellScriptBin
}:
let
  libraryPaths = lib.escapeShellArgs (map lib.getLib [
    expat
    fontconfig
    freetype
    gcc-unwrapped
    glibc
    libpng
    libpng12
    libuuid
    zlib
  ]);

  # See the comments at the top of this file for what this is and why we're using it.
  interpreter = "${glibc}/lib/ld-linux-x86-64.so.2";

  # Common script text for both the patch-binary command and the patch-all-binaries
  # scripts.
  # The argType argument is for injecting an argument name: either "FILE" or "DIR",
  # depending on the script.
  #
  # This consumes the following option flags:
  # -f: Force - continue despite errors
  # -v: Verbose - output more logs
  # -d: Debug - output even more logs
  # -h: Help - calls the 'usage' function
  #
  # Each script has the same set of arguments: this allows us to forward the flags passed
  # to resolve-all-libraries to the patch-binary script without having to think or work
  # very hard at it.
  commonText = argType: ''
    # Use $self as a friendly alias for $0. Both patch-binary and resolve-all-libraries
    # are stored in a path like /nix/store/<hash>-foo/bin/foo, which is both long and not
    # of much use to an end user. We can use basename to extract just the filename, which
    # is sufficient for our purposes.
    self="$(basename "$0")"

    usage() {
      # Allow setting a different exit code (but default to an error exit)
      local code="''${1:-1}"

      # If we're exiting with a non-zero code, then replace standard output with standard
      # error. During a Docker build, this will show up as red on the user's terminal,
      # which will hopefully alert them to an issue.
      # (This global redirection is safe because we'll be unconditionally exiting at the
      # end of this function, so we're not clobbering anyone else's output streams.)
      if test "$code" -gt 0; then
        exec >&2
      fi

      echo "USAGE: $self [-d] [-vv] [-f] ${argType} [${argType} ...]"
      echo "USAGE: $self -h"
      echo
      echo $'  -h\tDisplay this help'
      echo $'  -f\tContinue even if errors occur'
      echo $'  -v\tOutput more logs'
      echo $'  -vv\tOutput debug-level logs'

      exit "$code"
    }

    is_force=
    verbosity=0

    while getopts "vfh" option; do
      case "$option" in
        f)
          is_force=1
          ;;

        v)
          verbosity=$((verbosity+1))
          ;;

        h)
          # When the user asks for help, don't exit with an error code
          usage 0
          ;;

        *)
          usage
          ;;
      esac
    done

    # Remove all of the arguments we've parsed
    shift $((OPTIND-1))

    is-force() {
      test -n "$is_force"
    }

    is-debug() {
      test "$verbosity" -ge 2
    }

    is-verbose() {
      test "$verbosity" -ge 1
    }

    debug() {
      if is-debug; then
        echo "DEBUG:" "$@"
      fi
    }

    verbose() {
      if is-verbose; then
        echo "$@"
      fi
    }

    warning() {
      echo "WARNING:" "$@" >&2
    }

    error() {
      echo "ERROR:" "$@" >&2
    }
  '';

  # Script to patch a list of binaries to resolve all of their dependencies. This script
  # is not meant to be called directly, but instead invoked by resolve-all-libraries as
  # part of its `find' loop.
  # (NB. ''$ is Nix's escaping mechanism to avoid reading the { as the beginning of a Nix
  # variable interpolation.)
  patch-binary = writeShellScriptBin "patch-binary" ''
    set -euo pipefail
    export PATH="${lib.makeSearchPath "bin" [busybox patchelf]}"

    ${commonText "FILE"}

    # Fail if we received no arguments
    if test $# -eq 0; then
      usage
    fi

    # Build the list of library paths to scan (these will be /nix/store/[...]/lib)
    libraryPaths=(${libraryPaths})
    verbose "Scanning ''${#libraryPaths} paths"
    debug "Library paths:" "''${libraryPaths[@]}"

    # Read all *.so files into a list by using find to locate all shared libraries in the
    # libraryPaths variable. We use mapfile and -print0 to avoid issues with spaces in
    # filenames.
    mapfile -t -d $'\0' libraries < <(
      find "''${libraryPaths[@]}" \( -name '*.so' -o -name '*.so.*' \) -print0
    )

    # Create a map where the keys are dependencies (e.g. libz.so.1) and the values are
    # the library's path.
    declare -A dependencyCache
    for library in "''${libraries[@]}"; do
      dependencyCache["$(basename "$library")"]="$(dirname "$library")"
    done

    verbose "Registered ''${#dependencyCache[@]} libraries"
    debug "Registered libraries:" "''${!dependencyCache[@]}"

    # Clean up
    unset libraryPaths
    unset libraries

    # Count number of failures. If this is >0, then we need to exit with a non-zero code.
    # Note that we only increment this counter if the user didn't pass -f
    failures=0

    for file in "$@"; do
      # ELF header: 7f 45 4c 46 (aka "\x7fELF")
      header="$(dd bs=1 count=4 if="$file" of=/dev/stdout 2>/dev/null)"
      if test "$header" != $'\x7fELF'; then
        # There are lots of files in a node_modules directory, so only output this at the
        # debug level.
        debug "Skipping non-binary $file"
        continue
      fi

      # Create an empty RPATH
      rpath=

      mapfile -t dependencies < <(patchelf --print-needed "$file")
      if is-verbose; then
        echo "Resolving libraries for $file:" "''${dependencies[@]}"
      else
        echo "Resolving libraries for $file"
      fi

      # Loop over patchelf's dependency listing
      for dependency in "''${dependencies[@]}"; do
        # Instead of using [[ -v ARRAY[KEY] ]] (which only works on some Bash versions), we
        # use fallback expansion to safely read a value without crashing on an unset array
        # key. We use the value x because it's guaranteed to be outside the domain of values
        # in this array: we're storing /nix/store paths, and so the x will never appear on
        # its own.
        if test "''${dependencyCache[$dependency]:-x}" == x; then
          if is-force; then
            # When -f is in effect, print a warning and continue
            warning "Unable to resolve the library ''${dependency} for $file"
            warning "Continuing since the -f flag was passed."
            continue
          fi

          # When not asked to force continue, treat this as a hard failure to avoid covering
          # up over hard-to-spot errors like ENOENT and EPIPE when scripts attempt to execute
          # the binary.
          error "Unable to resolve the library ''${dependency} for $file"
          error "This means that the program may not function correctly in this image."
          error "Please open a bug report and provide this error message."
          error "Alternatively, you can ignore this error by using the -f flag:"
          error
          error "    resolve-all-libraries -f DIR [DIR ...]"
          error

          # Hint to the user that they can get more output with the -v flag
          if ! is-verbose; then
            error "You can view more verbose output by passing -v to this command."
          elif ! is-debug; then
            error "You can view debug-level output by passing a second -v to this command."
          fi

          # Mark this as a failure, but continue: this way we'll be able to see all of the
          # resolution failures at once in order to avoid playing whack-a-mole with
          # dependency resolution.
          failures=$((failures+1))
          continue
        fi

        # It's safe to read from dependencyCache[$dependency] unconditionally since we've
        # exited this loop iteration on detecting error conditions.
        rpath="$rpath''${rpath+:}''${dependencyCache[$dependency]}"
      done

      # Update $file to use the Nix interpreter and our RPATH (search path), which has the
      # effect of resolving libraries that are needed.
      patchelf \
        --set-interpreter "${interpreter}" \
        --set-rpath "$rpath" \
        "$file"

      # Let patchelf remove redundancies that this script may have introduced
      patchelf --shrink-rpath "$file"
    done

    # Report a non-zero exit code to find
    if test "$failures" -gt 0; then
      exit 1
    fi
  '';

  # Script to scan one or more directories for library references that need to be resolved
  # against the image's Nix store. The most likely use case will be to run this command
  # in a Dockerfile:
  #
  # RUN set -ex \
  #  && npm install \
  #  && resolve-all-libraries node_modules
  #
  # The scanning logic is independent of the fact that it's going to be mostly used for
  # Node modules, but the list of libraries is biased towards
  resolve-all-libraries = writeShellScriptBin "resolve-all-libraries" ''
    set -euo pipefail
    export PATH="${lib.makeSearchPath "bin" [busybox]}"

    ${commonText "DIR"}

    # Fail if we received no arguments
    if test $# -eq 0; then
      usage
    fi

    # Array of arguments to pass to find's -exec parameter.
    exec_args=(${patch-binary}/bin/patch-binary)

    if is-verbose; then
      exec_args+=("-v")
    fi

    # Debug output just means another -v was passed
    if is-debug; then
      exec_args+=("-v")
    fi

    if is-force; then
      exec_args+=("-f")
    fi

    # Loop over each directory individually - we do this in order to more accurately
    # pinpoint the location in which errors occurred, which is made much more difficult
    # when passing the entirety of $@ to find in one go.
    for directory in "$@"; do
      if ! find "$directory" -type f -executable -exec ''${exec_args[@]} {} +; then
        if is-force; then
          warning "One or more libraries in $directory could not be resolved."
          warning "Continuing since the -f flag was passed."
        else
          error "One or more libraries in $directory could not be resolved."
          error "Review the error messages above to determine the best course of action."
          exit 1
        fi
      fi
    done
  '';
in
resolve-all-libraries
