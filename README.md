# ds_example

A minimal Nintendo DS cart: a moving bar on the top screen, a live key readout on
the bottom. Small enough to read in one sitting, and to copy when starting
something new.

## Use it

```sh
./build.sh            # -> hello.nds, about 70 KB
./run.sh              # play it
./run.sh shot.png     # or capture a screenshot and exit
```

Nothing to install by hand. `build.sh` builds the toolchain image on first use
(Docker caches it, so later builds are instant) and `run.sh` fetches the emulator
core. Both work on macOS and Linux. `./build.sh clean` removes the build products.

On hardware, copy `hello.nds` to a DS flashcart and pick it from the menu — on a
DSpico that means dropping it on the card and launching it in Pico Launcher. No
loader arguments, no firmware, no assets.

## What you should see

| screen | expect |
| --- | --- |
| top | a blue field with a **yellow bar moving across it**, left to right, forever |
| bottom | `DS example`, then `UP 0  DOWN 0 …` and `A 0  B 0 …` |

Press an arrow key (or a D-pad, if you have a controller mapped) and the numbers
on the bottom screen flip to 1. If they never change, the keys are not being
scanned — see below. START exits.

## The files

| | |
| --- | --- |
| `main.c` | the whole program, ~80 lines of commented C |
| `Makefile` | compile, link, and package into a `.nds` |
| `Dockerfile` | the toolchain ([BlocksDS](https://blocksds.skylyrac.net/)), so nothing is installed on your machine |
| `build.sh` / `run.sh` | the two commands above |
| `retroarch.cfg` | one line that turns off pause-on-unfocus, passed to RetroArch |

| `README.md` | this |

## What's actually in a DS program

Three things. The Makefile is mostly boilerplate around them:

| | |
| --- | --- |
| **The toolchain** | BlocksDS brings an ARM cross-compiler, `libnds`, and `ndstool`, which packs an ELF into a `.nds`. |
| **Two CPUs** | A DS has an ARM9 (your code runs there) and an ARM7 (sound, wifi, keypad hardware). Every cart ships a small ARM7 binary too — that's `ARM7ELF` in the Makefile, and `arm7_minimal.elf` is the stock one. |
| **The `.nds` container** | `ndstool` wraps both binaries, a header, and optionally an icon and banner. The header needs a game code and a title, and **the title is capped at 12 characters**. |

## Two things that bite everyone

Both are one line, and both fail as a *black screen* rather than an error, so
they are worth knowing before you spend an evening on them.

**`scanKeys()` refreshes the key state.** `keysHeld()` does not read hardware; it
returns what was last scanned. Forget the scan and the values never change, so
every button appears dead everywhere in your program:

```c
swiWaitForVBlank();
scanKeys();                     // <- without this, keysHeld() is frozen
uint16_t keys = keysHeld();
```

**VRAM must be mapped to match how you use it.** The screens have no memory of
their own; they read VRAM banks, and which bank serves which engine is something
the program sets. Ask for a framebuffer while the bank is still mapped as a
background and you get black:

```c
videoSetMode(MODE_FB0);         // top screen shows a framebuffer
vramSetBankA(VRAM_A_LCD);       // and here is its memory
```

## Presenting pixels

This example draws into a plain array and moves it with `dmaCopy` — simple, and
the usual thing for a first emulator frontend. Two alternatives:

* **A bitmap background** (`MODE_5_2D` + `BgType_Bmp16`) lets the 2D engine scale
  and position the image in hardware. If you are presenting a small console's
  frame on the DS's 256x192 screen, this is where the performance is.
* **Text on the bottom screen** comes free: `consoleDemoInit()` sets up a console
  and `printf` writes to it, with ANSI escapes for positioning (`\x1b[10;0H`),
  which is how the key display avoids scrolling the screen.

Use `printf`, not `iprintf`: BlocksDS is picolibc, and `iprintf` does not exist.

## Extending it

* **More source files:** add them to `OBJS` in the Makefile (`OBJS := main.o
  other.o`); the `%.o: %.c` rule picks them up.
* **Assets:** `ndstool` attaches a 32x32 icon and a banner with `-b`. Without
  them the cart shows a generic icon in the DS menu.
* **Exit back to a loader:** on a DSpico, Pico Launcher passes the file it opened
  in `argv[1]` — useful if you are writing something that opens ROMs.
* **Anything else:** the [libnds examples](https://github.com/blocksds/libnds)
  and the [BlocksDS docs](https://blocksds.skylyrac.net/docs/) cover video modes,
  sound, filesystem access and timers.

## Appendix: doing it by hand

What the scripts run, if you want to see it. All paths absolute, because the
common failure is running from a directory that does not hold the core —
RetroArch then finds nothing and exits with no useful message.

```sh
# the toolchain image, built once
docker build -t ds-example .
docker run --rm -v "$PWD:/work" ds-example make

# RetroArch and the melonDS core. run.sh works out the platform and, more subtly,
# the architecture of your RetroArch *binary* - which is not always the host's.
# The macOS cask is x86_64, so an Apple Silicon Mac still wants the x86_64 core.
brew install --cask retroarch                            # macOS
sudo apt install retroarch                               # Debian/Ubuntu

RA=/Applications/RetroArch.app/Contents/MacOS/RetroArch  # not on PATH on macOS
PLATFORM=apple/osx EXT=dylib                             # macOS
PLATFORM=linux     EXT=so                                # Linux
ARCH=x86_64                                              # aarch64 on ARM Linux

curl -LO "https://buildbot.libretro.com/nightly/$PLATFORM/$ARCH/latest/melonds_libretro.$EXT.zip"
unzip -o "melonds_libretro.$EXT.zip"                     # or: python3 -m zipfile -e

# Note the --appendconfig below: it points at retroarch.cfg, which turns off
# pause-on-unfocus. RetroArch pauses when its window loses focus, the DS stops
# booting, and the capture comes out blank. It is passed as an *append* config so
# your own RetroArch settings still apply.

# run 200 frames, save the last, exit. Drop --max-frames to just play instead.
"$RA" -L "$PWD/melonds_libretro.$EXT" "$PWD/hello.nds" --appendconfig="$PWD/retroarch.cfg" \
    --max-frames=200 --max-frames-ss --max-frames-ss-path="$PWD/shot.png"
```

`shot.png` is 1345x2018: the two DS screens stacked, top above bottom.

While it runs, melonDS prints about one `unknown arm7 write32 ...` line per
frame. That is the emulator logging an ARM7 access it does not implement — the
message is in the core, and any DS app produces the same rate. It is not an
error, and on hardware those accesses are handled normally. It goes to stdout, so
`>/dev/null` silences it.

## Licence

Zlib, matching the DS homebrew ecosystem. Do whatever you like with it.
