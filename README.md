# Images for Gesso 1.x, F1UX, and F1Omega (Experimental)

## About

This repo builds multiple images for old (pre-`node-sass`) ForumOne themes. Images are broken down by the available Node, PHP, and Ruby versions installed - this is done in case there are version compatibility issues with software.

## Versions Supported

| Node Version | PHP Version | Ruby Version | Image Tag                 |
| ------------ | ----------- | ------------ | ------------------------- |
| v4           | 7.1         | 2.3          | node-v4-php-7.1-ruby-2.3  |
| v4           | 7.2         | 2.3          | node-v4-php-7.2-ruby-2.3  |
| v4           | 7.3         | 2.3          | node-v4-php-7.3-ruby-2.3  |
| v6           | 7.1         | 2.3          | node-v6-php-7.1-ruby-2.3  |
| v6           | 7.2         | 2.3          | node-v6-php-7.2-ruby-2.3  |
| v6           | 7.3         | 2.3          | node-v6-php-7.3-ruby-2.3  |
| v8           | 7.1         | 2.3          | node-v8-php-7.1-ruby-2.3  |
| v8           | 7.2         | 2.3          | node-v8-php-7.2-ruby-2.3  |
| v8           | 7.3         | 2.3          | node-v8-php-7.3-ruby-2.3  |
| v10          | 7.1         | 2.3          | node-v10-php-7.1-ruby-2.3 |
| v10          | 7.2         | 2.3          | node-v10-php-7.2-ruby-2.3 |
| v10          | 7.3         | 2.3          | node-v10-php-7.3-ruby-2.3 |
| v12          | 7.1         | 2.3          | node-v12-php-7.1-ruby-2.3 |
| v12          | 7.2         | 2.3          | node-v12-php-7.2-ruby-2.3 |
| v12          | 7.3         | 2.3          | node-v12-php-7.3-ruby-2.3 |

## Requirements

- Docker
- Nix (see [installation instructions](https://nixos.org/nix/download.html))

## Build Instructions

### Building All Images

These two commands will build and load all available images into the local Docker daemon. Note that it will take some time to compile the dependencies once this is completed

```sh
nix-build
for file in result/*.tar.gz; do
  docker load <$file
done
```

### Building One Image

This will build and load a single image.

```sh
# Change this to the tag you want to build
tag="node-v10-php-7.1-ruby-2.3"

nix-build images.nix -A \"$tag\"
docker load <result
```

## Organization

This repository is organized into files that represent one or more _derivations_ (think "package" that you'd install with apt-get or brew). The files are listed here in roughly dependency order:

Docker images:

- `default.nix` - this is the file that `nix-build` picks up by default. When built, the output directory will be one tarball for each row in the versions table.
- `images.nix` - this file is an attribute set (think JS object or PHP array) where each key is a Docker image tag, and the value is the derivation for that image.

Node:

- `node.nix` - this file is an attribute set keyed by Node major version (e.g., `v4` or `v12`) where the values are Node derivations.
- `grunt.nix` - this file builds Grunt against a Node from `node.nix`.

PHP:

- `php.nix` - this file is an attribute set keyed by PHP minor version (e.g., `7.1` or `7.3`) where the values are PHP derivations.
- `composer.nis` - this file builds Composer against a PHP from `php.nix`.

Ruby:

- `ruby.nix` - this file is an attribute set keyed by Ruby mnior version (e.g., `2.3`) where the values are Ruby derivations.
- `bundler.nix` - this file builds Bundler against a Ruby from `ruby.nix`.

If you are looking to understand the build flow, then start with `images.nix` and go to the Node, PHP, and/or Ruby derivations from there.

## Post-Build Cleanup

### Caveats

If you're done with the builds here, you can ask Nix to collect garbage from its store. This will remove anything that does not have a root (i.e., a link from outside the store).

There are two suggestions to avoid accidentally purging build artifacts:

1. Run `nix-build` to persist the image tarballs themselves
2. Run `nix-build roots.nix -o roots` to persist the interpreters built for the images

If these two are run, then you will only purge the intermediate artifacts and build tooling, which are relatively easy to re-fetch or regenerate.

### Cleaning Up

This command will remove unused store paths (remember to read the "caveats" section!):

```sh
nix-collect-garbage
```

You can also ask Nix to optimize the remaining store paths with the below command.

```sh
nix-store --optimize
```

## Support

These images are currently experimental and should not be considered supported until they are stabilized.

## License

This software is available under the MIT License. See [LICENSE](LICENSE) for details.
