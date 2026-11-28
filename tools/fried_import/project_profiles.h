#pragma once

#include "value.h"

#include <string>

namespace fried_import
{
    // Puts a project into the layout where "platforms" is a map with a profile for each platform the project builds for, and returns true when the project was written in the older layout: "platforms" as a list of names and the settings of each platform in a section of the root. A project that declares no platforms comes out declaring all of them.
    bool normalizeProfiles(Value *project, std::string *error);

    // Gives each profile a "modules" map with the backend it uses for every module of the manifest: the profile's own choice, else the project's, else the module's default. A choice that does not exist, is planned, or does not run on the profile's platform is an error.
    bool resolveModules(Value *project, const Value &manifest, std::string *error);
}
