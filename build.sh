#!/bin/sh
# Build hello.nds. Nothing to install: the toolchain lives in the Docker image,
# which is built once and cached.
#
#   ./build.sh          build
#   ./build.sh clean    remove the build products
set -eu
cd "$(dirname "$0")"

docker build -q -t ds-example . > /dev/null
docker run --rm -v "$PWD:/work" ds-example make "$@"
