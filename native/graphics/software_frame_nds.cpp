#include "graphics/software_frame.h"

#include <nds.h>

#include <algorithm>

// The top screen shows a 256x192 16-bit bitmap background of the main 2D
// engine, out of VRAM bank A. Drawing goes into a frame in main RAM instead,
// which the ARM9 reaches through its data cache where VRAM is uncached, and
// at the vertical blank the cache is written back and the DMA copies the frame
// across, so the screen never shows half a frame.

namespace
{
    constexpr int s_width = 256;
    constexpr int s_height = 192;
    constexpr int s_frameBytes = s_width * s_height * 2;

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
        videoSetMode(MODE_5_2D);
        vramSetBankA(VRAM_A_MAIN_BG);
        setBackdropColor(0);
        int background = bgInit(3, BgType_Bmp16, BgSize_B16_256x256, 0, 0);
        s_screen = bgGetGfxPtr(background);
    }
    return fried_software_frame_get(windowId);
}

void fried_software_frame_close(int)
{
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

void fried_software_frame_present(int)
{
    if (!s_screen)
    {
        return;
    }
    DC_FlushRange(s_frame, s_frameBytes);
    swiWaitForVBlank();
    dmaCopyWords(3, s_frame, s_screen, s_frameBytes);
}

bool fried_software_frame_has_vsync(int)
{
    return true;
}
