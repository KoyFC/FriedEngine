#include "graphics/texture.h"

#include "last_error.h"


int fried_texture_load_memory(int, const unsigned char *, int)
{
    fried_set_last_error("This platform loads textures only from files");
    return -1;
}
