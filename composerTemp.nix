# Helper derivation to install a world-writable /tmp directory in a Docker image.
# Composer uses this path during installation, so we create the derivation here to share
# it with Composer-using images.
{ runCommand }:
runCommand "tmpdir" {} ''
  mkdir -p $out/tmp
  chmod 0777 $out/tmp
''
