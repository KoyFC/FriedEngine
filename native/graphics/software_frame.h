#pragma once

#include <cstdint>

// What a platform whose drawing is done by the CPU gives renderer_software.cpp:
// a 16-bit frame per window in the screen's own pixel format, and the few
// operations on a whole frame that its hardware does better than a loop.

#ifdef TARGET_FXCG50
// RGB565. Blending spreads a colour's fields apart in 32 bits, green high and
// red and blue low, so one multiplication blends all three.
constexpr uint32_t FRIED_SOFTWARE_LOW_FIELDS = 0xF81F;
constexpr uint32_t FRIED_SOFTWARE_HIGH_FIELD = 0x07E0;
constexpr uint16_t FRIED_SOFTWARE_OPAQUE_BIT = 0;

inline uint16_t fried_software_pack(int r, int g, int b)
{
    return (uint16_t)(((r & 0xf8) << 8) | ((g & 0xfc) << 3) | (b >> 3));
}

inline int fried_software_red(uint16_t pixel)
{
    return (pixel >> 8) & 0xf8;
}

inline int fried_software_green(uint16_t pixel)
{
    return (pixel >> 3) & 0xfc;
}

inline int fried_software_blue(uint16_t pixel)
{
    return (pixel << 3) & 0xf8;
}
#elif defined(__NDS__)
// BGR555, which a 16-bit bitmap background only shows where the top bit is
// set. Spread apart the way RGB565 is, with green high and red and blue low.
constexpr uint32_t FRIED_SOFTWARE_LOW_FIELDS = 0x7C1F;
constexpr uint32_t FRIED_SOFTWARE_HIGH_FIELD = 0x03E0;
constexpr uint16_t FRIED_SOFTWARE_OPAQUE_BIT = 0x8000;

inline uint16_t fried_software_pack(int r, int g, int b)
{
    return (uint16_t)(FRIED_SOFTWARE_OPAQUE_BIT | ((b & 0xf8) << 7) | ((g & 0xf8) << 2) | (r >> 3));
}

inline int fried_software_red(uint16_t pixel)
{
    return (pixel << 3) & 0xf8;
}

inline int fried_software_green(uint16_t pixel)
{
    return (pixel >> 2) & 0xf8;
}

inline int fried_software_blue(uint16_t pixel)
{
    return (pixel >> 7) & 0xf8;
}
#endif

// Rows are m_width pixels apart and start on four bytes.
struct FriedSoftwareFrame
{
    uint16_t *m_pixels;
    int m_width;
    int m_height;
};

// Between open and close a renderer draws into the window's frame.
FriedSoftwareFrame fried_software_frame_open(int windowId);
void fried_software_frame_close(int windowId);

FriedSoftwareFrame fried_software_frame_get(int windowId);

// Fills the whole frame, replacing what is there.
void fried_software_frame_clear(int windowId, uint16_t color);

// Fills output pixels opaquely, right and bottom excluded.
void fried_software_frame_fill(int windowId, int left, int top, int right, int bottom, uint16_t color);

// Sends the frame's rows from top to bottom, bottom excluded, the only ones
// drawn since the last present; with none, top is not above bottom.
void fried_software_frame_present(int windowId, int top, int bottom);
bool fried_software_frame_has_vsync(int windowId);

// Whether the screen stopped showing the frame since the last call, so all of
// it has to be drawn and sent again.
bool fried_software_frame_take_lost(int windowId);

#ifdef TARGET_FXCG50
// The main menu, or a world switch, has had the screen.
void fried_software_frame_lose();
#endif
