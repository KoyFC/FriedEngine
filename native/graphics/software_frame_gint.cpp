#include "graphics/software_frame.h"

#include <gint/display.h>

// gint draws into a 396x224 RGB565 frame in memory, which dupdate() sends to
// the screen. There is one frame, and the one window is the whole of it.
//
// gint reaches the frame through an address that skips the CPU's cache, so
// the DMA that sends it and the one that clears it never find a stale copy.
// Blending reads every pixel it draws over, and each of those reads went out
// to memory, so the frame is reached through the cache here instead, and the
// cache is kept in step by hand on either side of the two transfers.

namespace
{
    constexpr uintptr_t s_physicalMask = 0x1fffffff;
    constexpr uintptr_t s_cachedArea = 0x80000000;
    constexpr uintptr_t s_uncachedArea = 0xa0000000;
    constexpr uintptr_t s_cacheLine = 32;

    uint16_t *inArea(uint16_t *frame, uintptr_t area)
    {
        return (uint16_t *)(((uintptr_t)frame & s_physicalMask) | area);
    }

    void useFrameThrough(uintptr_t area)
    {
        uint16_t *frame = inArea(gint_vram, area);
        dsetvram(frame, frame);
    }

    // gint aligns the frame to cache lines, so no other data shares one.
    template <typename Operation>
    void forEachFrameLine(Operation operation)
    {
        uintptr_t end = (uintptr_t)(gint_vram + DWIDTH * DHEIGHT);
        for (uintptr_t line = (uintptr_t)gint_vram; line < end; line += s_cacheLine)
        {
            operation(line);
        }
    }

    // What is drawn and still only in the cache goes out to memory, where the
    // DMA reads it from.
    void writeBackFrame()
    {
        forEachFrameLine([](uintptr_t line) { __asm__ volatile("ocbwb @%0" : : "r"(line) : "memory"); });
    }

    // The cached copy is dropped unwritten, ahead of a DMA that overwrites
    // all of the frame.
    void discardCachedFrame()
    {
        forEachFrameLine([](uintptr_t line) { __asm__ volatile("ocbi @%0" : : "r"(line) : "memory"); });
    }
}

FriedSoftwareFrame fried_software_frame_open(int windowId)
{
    useFrameThrough(s_cachedArea);
    return fried_software_frame_get(windowId);
}

void fried_software_frame_close(int)
{
    writeBackFrame();
    useFrameThrough(s_uncachedArea);
}

FriedSoftwareFrame fried_software_frame_get(int)
{
    return {gint_vram, DWIDTH, DHEIGHT};
}

void fried_software_frame_clear(int, uint16_t color)
{
    discardCachedFrame();
    dclear(color);
}

void fried_software_frame_fill(int, int left, int top, int right, int bottom, uint16_t color)
{
    drect(left, top, right - 1, bottom - 1, color);
}

void fried_software_frame_present(int)
{
    writeBackFrame();
    dupdate();
}

// dupdate() sends the frame as soon as it is called; nothing waits for the
// screen's refresh.
bool fried_software_frame_has_vsync(int)
{
    return false;
}
