#include "graphics/texture.h"

#include "last_error.h"

// The textures of these platforms are read from a file and nothing else, so a
// model that keeps an image inside itself is imported with the image beside it.

int fried_texture_load_memory(int, const unsigned char *, int)
{
    fried_set_last_error("This platform loads textures only from files");
    return -1;
}
