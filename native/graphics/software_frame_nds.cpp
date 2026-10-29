#include "graphics/software_frame.h"

#include <nds.h>

#include <algorithm>

// The bottom screen, when it is a window, shows a 256x192 16-bit bitmap
// background of the sub 2D engine, out of VRAM bank C, which the text console
// had until then. Drawing goes into a frame in main RAM instead, which the
// ARM9 reaches through its data cache where VRAM is uncached, and at the
// vertical blank the rows drawn are written back from the cache and the DMA
// copies them across, faster than the screen is drawn from them, so it never
// shows half a frame.

namespace
{
    constexpr int s_width = 256;
    constexpr int s_height = 192;

    // Cache lines are 32 bytes, so a write back covers the frame and nothing else.
    alignas(32) uint16_t s_frame[s_width * s_height];
    uint16_t *s_screen = nullptr;

    void fillRows(int left, int top, int right, int bottom, uint16_t color)
    {
        for (int y = top; y < bottom; ++y)
        {
            std::fill(s_frame + y * s_width + left, s_frame + y * s_width + right, color);
        }
    }
}

FriedSoftwareFrame fried_software_frame_open(int windowId)
{
    if (!s_screen)
    {
        // The console's font and map are still in the bank, and would show as
        // noise until the first frame is presented.
        videoSetModeSub(MODE_5_2D);
        vramSetBankC(VRAM_C_SUB_BG);
        setBackdropColorSub(0);
        dmaFillWords(0, BG_BMP_RAM_SUB(0), s_width * s_height * 2);
        int background = bgInitSub(3, BgType_Bmp16, BgSize_B16_256x256, 0, 0);
        s_screen = bgGetGfxPtr(background);
    }
    return fried_software_frame_get(windowId);
}

void fried_software_frame_close(int)
{
    s_screen = nullptr;
}

FriedSoftwareFrame fried_software_frame_get(int)
{
    return {s_frame, s_width, s_height};
}

void fried_software_frame_clear(int, uint16_t color)
{
    fillRows(0, 0, s_width, s_height, color);
}

void fried_software_frame_fill(int, int left, int top, int right, int bottom, uint16_t color)
{
    fillRows(left, top, right, bottom, color);
}

void fried_software_frame_present(int, int top, int bottom)
{
    if (!s_screen || top >= bottom)
    {
        return;
    }
    const uint16_t *rows = s_frame + top * s_width;
    int bytes = (bottom - top) * s_width * 2;
    DC_FlushRange(rows, bytes);
    swiWaitForVBlank();
    dmaCopyWords(3, rows, s_screen + top * s_width, bytes);
}

// Nothing else draws on the bottom screen while a window has it.
bool fried_software_frame_take_lost(int)
{
    return false;
}

bool fried_software_frame_has_vsync(int)
{
    return true;
}
