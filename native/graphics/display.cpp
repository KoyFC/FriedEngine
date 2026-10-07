#include "graphics/display.h"

#include <algorithm>
#include <cmath>

#ifndef FRIED_DISPLAY_MODE

FriedDisplayLayout fried_display_layout(int outputWidth, int outputHeight)
{
    return {outputWidth, outputHeight, 0, 0, outputWidth, outputHeight, 1.0f, 1.0f};
}

#else

namespace
{
    constexpr FriedDisplayMode s_mode = FRIED_DISPLAY_MODE;
    constexpr int s_designWidth = FRIED_DISPLAY_WIDTH;
    constexpr int s_designHeight = FRIED_DISPLAY_HEIGHT;

    FriedDisplayLayout centeredInOutput(int outputWidth, int outputHeight, float scale)
    {
        int viewportWidth = std::min(outputWidth, (int)std::lround(s_designWidth * scale));
        int viewportHeight = std::min(outputHeight, (int)std::lround(s_designHeight * scale));
        return {
            s_designWidth, s_designHeight,
            (outputWidth - viewportWidth) / 2, (outputHeight - viewportHeight) / 2,
            viewportWidth, viewportHeight,
            (float)viewportWidth / s_designWidth, (float)viewportHeight / s_designHeight,
        };
    }

    FriedDisplayLayout coveringOutput(int outputWidth, int outputHeight, int logicalWidth, int logicalHeight)
    {
        return {
            logicalWidth, logicalHeight,
            0, 0, outputWidth, outputHeight,
            (float)outputWidth / logicalWidth, (float)outputHeight / logicalHeight,
        };
    }
}

FriedDisplayLayout fried_display_layout(int outputWidth, int outputHeight)
{
    // A minimized window has no output to scale to.
    if (outputWidth <= 0 || outputHeight <= 0)
    {
        return {s_designWidth, s_designHeight, 0, 0, 0, 0, 1.0f, 1.0f};
    }

    float fitScale = std::min((float)outputWidth / s_designWidth, (float)outputHeight / s_designHeight);

    switch (s_mode)
    {
    case FriedDisplayMode::Integer:
        // Below a scale of 1 the game would be cropped, so it shrinks as fit does.
        return centeredInOutput(outputWidth, outputHeight, fitScale < 1.0f ? fitScale : std::floor(fitScale));
    case FriedDisplayMode::Expand:
        return coveringOutput(
            outputWidth, outputHeight,
            std::max(1, (int)std::lround(outputWidth / fitScale)),
            std::max(1, (int)std::lround(outputHeight / fitScale)));
    case FriedDisplayMode::Stretch:
        return coveringOutput(outputWidth, outputHeight, s_designWidth, s_designHeight);
    default:
        return centeredInOutput(outputWidth, outputHeight, fitScale);
    }
}

#endif

bool fried_display_filters_linearly()
{
#ifdef FRIED_DISPLAY_LINEAR_FILTER
    return true;
#else
    return false;
#endif
}

namespace
{
    float snapEdge(float logical, float scale)
    {
        return std::round(logical * scale) / scale;
    }
}

FriedRect fried_display_snap(float x, float y, float width, float height, float scaleX, float scaleY)
{
    float left = snapEdge(x, scaleX);
    float top = snapEdge(y, scaleY);
    return {left, top, snapEdge(x + width, scaleX) - left, snapEdge(y + height, scaleY) - top};
}
