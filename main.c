// SPDX-License-Identifier: Zlib
//
// The smallest useful Nintendo DS program: text on the bottom screen, pixels on
// the top, keys read every frame. Everything here is libnds (BlocksDS).
//
// Three things bite everyone once, so they are called out below: scanKeys() is
// what refreshes the key state, VRAM has to be mapped to match how you use it --
// a bitmap background needs a bank mapped as a background -- and sound needs
// soundEnable() called once at startup.

#include <nds.h>
#include <stdio.h>

#define W 256
#define H 192

// --- sound -----------------------------------------------------------------
//
// The blip is generated at startup rather than loaded from a file, so the cart
// still has no assets. One buffer played back at different rates gives every
// button its own pitch, which is the cheapest way to hear which is which.
#define TONE_SAMPLES 512
#define TONE_RATE    22050

static s16 tone[TONE_SAMPLES];

static void initTone(void)
{
    for (int i = 0; i < TONE_SAMPLES; i++) {
        int level = ((i / 16) & 1) ? 8000 : -8000;            // a square wave,
        tone[i] = level * (TONE_SAMPLES - i) / TONE_SAMPLES;  // faded out
    }

    // Starts the ARM7 sound driver: without it, silence.
    soundEnable();
}

// percent is a percentage of TONE_RATE, so 100 is the pitch above.
static void blip(int percent)
{
    soundPlaySample(tone, SoundFormat_16Bit, sizeof(tone),
                    TONE_RATE * percent / 100, 100, 64, false, 0);
}

// One entry per button that makes a sound. The pitch rises across the face
// buttons and the D-pad sits in the middle, so a swapped mapping is obvious.
static const struct {
    uint16_t mask;
    const char *name;
    int pitch;
} blips[] = {
    { KEY_A,      "A",      75 }, { KEY_B,      "B",      90 },
    { KEY_X,      "X",     105 }, { KEY_Y,      "Y",     120 },
    { KEY_L,      "L",     135 }, { KEY_R,      "R",     150 },
    { KEY_UP,     "UP",    100 }, { KEY_DOWN,   "DOWN",   80 },
    { KEY_LEFT,   "LEFT",   70 }, { KEY_RIGHT,  "RIGHT", 130 },
    { KEY_START,  "START",  60 }, { KEY_SELECT, "SELECT", 55 },
};

int main(void)
{
    int frame = 0, blipsPlayed = 0;
    const char *lastBlip = "-";

    // Bottom screen: a text console. consoleDemoInit() handles the mode, the
    // VRAM and the print stream, so printf() just works.
    consoleDemoInit();
    initTone();                              // <- without this there is no sound

    // Top screen: a framebuffer, driven through VRAM_A. This is the simplest
    // way to present pixels and it is what an emulator frontend usually does:
    // draw into a normal buffer, then DMA it across.
    videoSetMode(MODE_FB0);
    vramSetBankA(VRAM_A_LCD);                // <- without this the screen is black

    // The frame is built here and DMA'd to VRAM_A each frame.
    static u16 pixels[W * H];

    printf("\x1b[0;0HDS example\n\n");
    printf("top screen: moving bar\n");
    printf("bottom: key state\n");
    printf("press a button: it blips\n\n");
    printf("press START to exit\n");

    for (;;) {
        uint16_t keys, down;

        // One frame: wait for the screen, refresh the keys, do the work.
        swiWaitForVBlank();
        scanKeys();                          // <- without this keysHeld() never changes
        keys = keysHeld();
        down = keysDown();                   // pressed this frame, not held

        // A blip per button. keysDown(), not keysHeld(): a held key would
        // retrigger every frame at 60 Hz.
        for (unsigned i = 0; i < sizeof(blips) / sizeof(blips[0]); i++)
            if (down & blips[i].mask) {
                blip(blips[i].pitch);
                lastBlip = blips[i].name;
                blipsPlayed++;
            }

        // Paint the top screen: a moving vertical bar over a blue field.
        for (int y = 0; y < H; y++) {
            u16 *row = pixels + y * W;
            for (int x = 0; x < W; x++)
                row[x] = RGB15(0, 0, 16);
        }
        for (int x = frame % W; x < frame % W + 16 && x < W; x++)
            for (int y = 0; y < H; y++)
                pixels[y * W + x] = RGB15(31, 31, 0);
        frame++;

        dmaCopy(pixels, VRAM_A, W * H * 2);

        // Bottom screen: show what the keys are doing, in place, so the console
        // does not scroll.
        printf("\x1b[9;0HUP %d  DOWN %d  LEFT %d  RIGHT %d    ",
                !!(keys & KEY_UP), !!(keys & KEY_DOWN),
                !!(keys & KEY_LEFT), !!(keys & KEY_RIGHT));
        printf("\x1b[10;0HA %d  B %d  X %d  Y %d  L %d  R %d    ",
                !!(keys & KEY_A), !!(keys & KEY_B), !!(keys & KEY_X),
                !!(keys & KEY_Y), !!(keys & KEY_L), !!(keys & KEY_R));
        // Counted as well as played, so a screenshot can show whether the
        // trigger fired -- useful when there is no speaker to listen to.
        printf("\x1b[12;0Hblips %d  last %-6s    ", blipsPlayed, lastBlip);

        if (keys & KEY_START)
            break;
    }

    return 0;
}
