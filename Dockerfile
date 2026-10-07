# The toolchain: BlocksDS is a modern open-source DS SDK (devkitARM-based
# toolchain, libnds, ndstool). The `slim` tag has everything but the examples.
FROM skylyrac/blocksds:slim-latest

RUN apt-get update \
 && apt-get install -y --no-install-recommends make \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /work
