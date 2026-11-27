#pragma once

#include "value.h"

#include <string>

namespace fried_import
{
    // Reads the Fried YAML subset, which is a superset of JSON. The error starts with "line:column: ".
    bool parseYaml(const std::string &text, Value *value, std::string *error);

    // The value as compact JSON, which CMake reads with string(JSON ...).
    std::string toJson(const Value &value);
}
