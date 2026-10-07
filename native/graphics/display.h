#pragma once

enum class FriedDisplayMode
{
    Default,
    Fit,
    Integer,
    Expand,
    Stretch
};

// The viewport is in output pixels, the size in the game's logical ones.
struct FriedDisplayLayout
{
    int m_width;
    int m_height;
    int m_viewportX;
    int m_viewportY;
    int m_viewportWidth;
    int m_viewportHeight;
    float m_scaleX;
    float m_scaleY;
};

FriedDisplayLayout fried_display_layout(int outputWidth, int outputHeight);

bool fried_display_filters_linearly();

struct FriedRect
{
    float m_x;
    float m_y;
    float m_width;
    float m_height;
};

// Moves each edge to the nearest output pixel, so images drawn side by side
// still meet and a moving one steps by whole pixels along with the rest.
FriedRect fried_display_snap(float x, float y, float width, float height, float scaleX, float scaleY);
