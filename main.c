// SPDX-License-Identifier: Zlib
//
// The smallest useful Nintendo DS program: text on the bottom screen, pixels on
// the top, keys read every frame. Everything here is libnds (BlocksDS).
//
// Two things bite everyone once, so they are called out below: scanKeys() is
// what refreshes the key state, and VRAM has to be mapped to match how you use
// it -- a bitmap background needs a bank mapped as a background.

#include <nds.h>
#include <stdio.h>

#define W 256
#define H 192

int main(void)
{
    int frame = 0;

    // Bottom screen: a text console. consoleDemoInit() handles the mode, the
    // VRAM and the print stream, so printf() just works.
    consoleDemoInit();

    // Top screen: a framebuffer, driven through VRAM_A. This is the simplest
    // way to present pixels and it is what an emulator frontend usually does:
    // draw into a normal buffer, then DMA it across.
    videoSetMode(MODE_FB0);
    vramSetBankA(VRAM_A_LCD);                // <- without this the screen is black

    // The frame is built here and DMA'd to VRAM_A each frame.
    static u16 pixels[W * H];

    printf("\x1b[0;0HDS example\n\n");
    printf("top screen: moving bar\n");
    printf("bottom: key state\n\n");
    printf("press START to exit\n");

    for (;;) {
        uint16_t keys;

        // One frame: wait for the screen, refresh the keys, do the work.
        swiWaitForVBlank();
        scanKeys();                          // <- without this keysHeld() never changes
        keys = keysHeld();

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

        if (keys & KEY_START)
            break;
    }

    return 0;
}
