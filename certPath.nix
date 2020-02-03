# Helper derivation to copy pkgs.cacert's ca-bundle.crt to a place that OpenSSL expects
# to find it when doing peer validation.
{
  runCommand
, cacert
}:
runCommand "certPath" {} ''
  dest="$out/etc/ssl/certs"
  mkdir -p "$dest"

  ln -s "${cacert}/etc/ssl/certs/ca-bundle.crt" "$out/etc/ssl/certs/ca-certificates.crt"
''
