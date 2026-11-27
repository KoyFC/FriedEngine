#pragma once

#include "value.h"

#include <string>
#include <vector>

namespace fried_import
{
    // Turns the data of a scene file into the .fscene the engine reads without parsing text. Refuses what the engine would refuse at load, so the build fails instead of the console.
    bool compileScene(const Value &scene, const std::string &name, std::vector<unsigned char> *bytes, std::string *error);
}
