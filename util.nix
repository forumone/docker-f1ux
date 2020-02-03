{ lib }:
{
  # Usage:
  #   combineKeys [phpVersions.php74 nodeVersions.node12]
  # Combines the 'dockerKey' attr of derivations
  combineKeys = lib.concatMapStringsSep "-" (lib.getAttr "dockerKey");

  # Default Docker search $PATH for use in images
  dockerPath = builtins.concatStringsSep ":" [
    # Default $PATH used by Docker when it isn't present
    "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    # Make sure node CLIs (grunt & co) are accessible
    "/lib/node_modules/.bin"
  ];
}
