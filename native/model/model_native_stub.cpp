#include "model/model_native.h"

#include "last_error.h"


int fried_model_convert_file(const char *)
{
    fried_set_last_error("This platform loads only models that were imported");
    return -1;
}

int fried_model_get_size(int)
{
    return -1;
}

void fried_model_copy(int, unsigned char *)
{
}

void fried_model_release(int)
{
}
