#pragma once

// The model converter, for a game that reads a model it is given as an OBJ or a glTF file: on PC a game that is being edited has the project's own
// assets, which the asset import tool has not turned into FRMS. Everywhere else a model has been imported, so these have nothing to convert.
extern "C"
{
    // Converts the file, whose path is a file of the platform's, and returns a handle for the bytes it made, or -1 with a reason in fried_last_error().
    int fried_model_convert_file(const char *path);
    int fried_model_get_size(int handle);
    void fried_model_copy(int handle, unsigned char *out);
    void fried_model_release(int handle);
}
