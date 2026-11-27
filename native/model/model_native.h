#pragma once

extern "C"
{
    int fried_model_convert_file(const char *path);
    int fried_model_get_size(int handle);
    void fried_model_copy(int handle, unsigned char *out);
    void fried_model_release(int handle);
}
