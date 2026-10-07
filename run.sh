#!/bin/sh
# Play hello.nds, or capture a screenshot of it. macOS and Linux.
#
#   ./run.sh              play it (opens a window; close it to stop)
#   ./run.sh shot.png     run 200 frames, save the last one, exit
#
# If a guess is wrong, both can be overridden:
#   RA=/path/to/retroarch   a particular RetroArch
#   CORE_ARCH=x86_64        a particular core build
set -eu
cd "$(dirname "$0")"

OUT=${1:-}
OS=$(uname -s)

case "$OS" in
    Darwin) PLATFORM=apple/osx; EXT=dylib ;;
    Linux)  PLATFORM=linux;     EXT=so ;;
    *) echo "unsupported platform: $OS" >&2; exit 1 ;;
esac

# --- RetroArch -------------------------------------------------------------
# Not on PATH on macOS, where the cask installs an app bundle. Usually on PATH on
# Linux. RA may be several words, e.g. "flatpak run org.libretro.RetroArch",
# which is why it is used unquoted below.
RA=${RA:-}
if [ -z "$RA" ]; then
    if command -v retroarch > /dev/null 2>&1; then
        RA=$(command -v retroarch)
    elif [ -x /Applications/RetroArch.app/Contents/MacOS/RetroArch ]; then
        RA=/Applications/RetroArch.app/Contents/MacOS/RetroArch
    else
        cat >&2 <<'MSG'
No RetroArch found. Install it, or point RA at one:

  macOS     brew install --cask retroarch
  Debian    sudo apt install retroarch
  Flatpak   flatpak install flathub org.libretro.RetroArch
            RA="flatpak run org.libretro.RetroArch" ./run.sh shot.png

To build the cart without running it, use ./build.sh.
MSG
        exit 1
    fi
fi

# --- the emulator core -----------------------------------------------------
# It must match the architecture of the RetroArch *binary*, which is not always
# the host's: the macOS cask is x86_64 and runs under Rosetta on Apple Silicon,
# where uname says arm64.
detect_arch() {
    file -b "$1" 2>/dev/null | tr ' /,' '\n\n\n' | grep -xE 'x86_64|arm64|aarch64' | head -1
}
ARCH=${CORE_ARCH:-}
[ -n "$ARCH" ] || ARCH=$(detect_arch "${RA%% *}" || true)
[ -n "$ARCH" ] || ARCH=$(uname -m)          # no `file` on some Linux systems
case "$ARCH" in
    x86-64|x86_64|amd64) ARCH=x86_64 ;;
    arm64|aarch64)       ARCH=$([ "$OS" = Linux ] && echo aarch64 || echo arm64) ;;
    *) echo "unsupported architecture '$ARCH' - set CORE_ARCH" >&2; exit 1 ;;
esac

CORE=melonds_libretro.$EXT
if [ ! -f "$CORE" ]; then
    echo "fetching the melonDS core ($PLATFORM/$ARCH)..."
    curl -sLO "https://buildbot.libretro.com/nightly/$PLATFORM/$ARCH/latest/$CORE.zip"

    if command -v unzip > /dev/null 2>&1; then
        unzip -oq "$CORE.zip"
    elif command -v python3 > /dev/null 2>&1; then
        python3 -m zipfile -e "$CORE.zip" .
    else
        echo "need unzip or python3 to unpack $CORE.zip" >&2; exit 1
    fi

    [ -f "$CORE" ] || { echo "no $CORE in that download - wrong CORE_ARCH?" >&2; exit 1; }
fi

# Without this, RetroArch pauses when its window is not focused, the DS stops
# booting, and a capture comes out blank. RetroArch ignores an --appendconfig it
# cannot find, so a missing file here would fail as a blank screenshot.
[ -f retroarch.cfg ] || { echo "retroarch.cfg is missing" >&2; exit 1; }

[ -f hello.nds ] || ./build.sh

# $RA is unquoted on purpose: it may be "flatpak run ..." (see above).
if [ -n "$OUT" ]; then
    $RA -L "$PWD/$CORE" "$PWD/hello.nds" --appendconfig="$PWD/retroarch.cfg" \
        --max-frames=200 --max-frames-ss --max-frames-ss-path="$PWD/$OUT" \
        > /dev/null 2>&1

    if [ -f "$OUT" ]; then
        echo "$OUT"
    else
        echo "no screenshot: RetroArch exited without writing $OUT" >&2
        echo "  run it without the frame cap to see what it says:" >&2
        echo "  $RA -L \"$PWD/$CORE\" \"$PWD/hello.nds\" --appendconfig=\"$PWD/retroarch.cfg\"" >&2
        exit 1
    fi
else
    # stderr is left alone here: if it fails to start, you want to see why.
    $RA -L "$PWD/$CORE" "$PWD/hello.nds" --appendconfig="$PWD/retroarch.cfg" > /dev/null
fi
