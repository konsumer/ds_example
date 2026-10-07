#!/bin/sh
# Build hello.nds.
#
#   ./build.sh          build
#   ./build.sh clean    remove the build products
#
# The toolchain is the official BlocksDS image, pulled on first use. There is no
# Dockerfile and no Makefile: this is one compile, one link and one ndstool call,
# so they live here, where you can read them. Every .c in the directory is built,
# so adding a file needs no edit.
set -eu
cd "$(dirname "$0")"

IMAGE=${IMAGE:-skylyrac/blocksds:slim-latest}

if [ "${1:-}" = clean ]; then
    rm -f ./*.o hello.elf hello.nds
    echo "cleaned"
    exit 0
fi

# --user so the files that come out belong to you and not to root. HOME and
# TMPDIR because the image's defaults point at /root, which that user cannot
# write. (No -t: a TTY is for typing in it, and it breaks in scripts.)
docker run --rm \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp -e TMPDIR=/tmp \
    -v "$PWD:/work" -w /work \
    "$IMAGE" \
    sh -euc '
        CC="$WONDERFUL_TOOLCHAIN/toolchain/gcc-arm-none-eabi/bin/arm-none-eabi-gcc"
        NDSTOOL="$BLOCKSDS/tools/ndstool/ndstool"
        ARM7="$BLOCKSDS/sys/arm7/main_core/arm7_minimal.elf"
        ARCH="-mthumb -mcpu=arm946e-s+nofp"
        SPECS="$BLOCKSDS/sys/crts/ds_arm9.specs"

        CFLAGS="$ARCH -O2 -specs=$SPECS -DARM9 -D__NDS__ -D__BLOCKSDS__ \
-I$BLOCKSDS/libs/libnds/include -Wall"
        LDFLAGS="$ARCH -specs=$SPECS -L$BLOCKSDS/libs/libnds/lib \
-Wl,--start-group -lnds9 -lc -Wl,--end-group"

        for c in ./*.c; do
            echo "  cc $c"
            "$CC" $CFLAGS -c -o "${c%.c}.o" "$c"
        done

        echo "  link hello.elf"
        "$CC" -o hello.elf ./*.o $LDFLAGS

        # -g is the game code ndstool writes into the header; the title is
        # capped at 12 characters.
        echo "  ndstool hello.nds"
        "$NDSTOOL" -c hello.nds -7 "$ARM7" -9 hello.elf -g RETR 01 hello
    '
