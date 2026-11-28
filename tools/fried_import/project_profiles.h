#pragma once

#include "value.h"

#include <string>

namespace fried_import
{
    // Puts a project into the layout where "platforms" is a map with a profile for each platform the project builds for, and returns true when the project was written in the older layout: "platforms" as a list of names and the settings of each platform in a section of the root. A project that declares no platforms comes out declaring all of them.
    bool normalizeProfiles(Value *project, std::string *error);
}
