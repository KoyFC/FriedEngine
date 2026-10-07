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
