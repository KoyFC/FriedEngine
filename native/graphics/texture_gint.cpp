#include "graphics/texture.h"

#include "last_error.h"

// gint has no image decoder, and this backend brings none, so no texture is
// ever created and every query answers as it does for a destroyed one.

int fried_texture_load(int, const char *)
{
    fried_set_last_error("Images cannot be loaded on the fx-CG50");
    return -1;
}

void fried_texture_destroy(int)
{
}

int fried_texture_get_width(int)
{
    return 0;
}

int fried_texture_get_height(int)
{
    return 0;
}

int fried_texture_get_downscale(int)
{
    return 0;
}
