# Creates a symbolic link to the 'env' command in a place that most tooling expects it
{
  runCommand,

  busybox
}:
runCommand "usr-bin-env" {} ''
  mkdir -p $out/usr/bin
  ln -s ${busybox}/bin/env $out/usr/bin/env
''
