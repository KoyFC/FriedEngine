#include "migrate_scenes.h"

#include "yaml.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <regex>
#include <set>
#include <sstream>

namespace fs = std::filesystem;

namespace fried_import
{
    namespace
    {
        typedef std::set<std::string> Names;

        struct EngineClass
        {
            std::string m_parent;
            std::string m_transform;
            std::string m_component;
            Names m_fields;
        };

        const Names s_transform2D = {"x", "y", "rotation", "scaleX", "scaleY"};
        const Names s_transform3D = {"x", "y", "z", "rotationX", "rotationY", "rotationZ", "scaleX", "scaleY", "scaleZ"};
        const Names s_rectTransform = {"anchorMinX", "anchorMinY", "anchorMaxX", "anchorMaxY", "pivotX", "pivotY", "offsetX", "offsetY", "insetLeft", "insetTop",
                                       "insetRight", "insetBottom", "width", "height", "rotation", "scaleX", "scaleY", "below"};
        const Names s_drawn = {"SpriteRenderer", "Label", "TextureRect", "Button", "TouchButton", "VirtualJoystick", "UIDocument", "Tilemap", "Collider2D", "Camera3D"};

        const std::map<std::string, EngineClass> &engineClasses()
        {
            static const std::map<std::string, EngineClass> classes = {
                {"Node", {"", "", "", {}}},
                {"CanvasItem", {"Node", "", "", {}}},
                {"Node2D", {"CanvasItem", "Transform2D", "", {}}},
                {"Node3D", {"CanvasItem", "Transform3D", "", {}}},
                {"Control", {"CanvasItem", "RectTransform", "", {}}},
                {"CanvasLayer", {"Node", "", "Canvas", {"layer"}}},
                {"KinematicBody", {"Node", "", "Body2D", {"velocityX", "velocityY"}}},
                {"Sprite", {"Node2D", "", "SpriteRenderer", {"texture", "source", "flip"}}},
                {"Camera", {"Node2D", "", "Camera", {"zoom"}}},
                {"Collider", {"Node2D", "", "Collider2D", {"width", "height", "collisionLayer", "collisionMask", "isTrigger", "isDebugVisible", "debugColor"}}},
                {"Tilemap", {"Node2D", "", "Tilemap", {"texture", "tileWidth", "tileHeight", "mapWidth", "mapHeight", "cells", "isSolid", "collisionLayer"}}},
                {"Label", {"Control", "", "Label", {"font", "text", "color", "maxWidth"}}},
                {"TextureRect", {"Control", "", "TextureRect", {"texture", "source", "flip"}}},
                {"Button", {"Control", "", "Button", {"font", "label", "color", "pressedColor", "borderColor", "labelColor"}}},
                {"TouchButton", {"Control", "", "TouchButton", {"action", "font", "label", "isPassBy", "platforms", "color", "pressedColor", "labelColor"}}},
                {"VirtualJoystick",
                 {"Control", "", "VirtualJoystick", {"action", "baseSize", "tipSize", "deadzone", "isDynamic", "isHiddenUntilTouched", "platforms", "baseColor", "tipColor"}}},
                {"UIDocument", {"Control", "", "UIDocument", {"document", "theme", "focusOnReady"}}},
                {"Camera3D", {"Node3D", "", "Camera3D", {"fieldOfView", "near", "far"}}},
                {"DirectionalLight", {"Node3D", "", "Light", {"ambient"}}},
                {"MeshInstance3D", {"Node3D", "", "MeshRenderer", {"mesh", "materialOverride"}}},
                {"MeshInstance", {"Node3D", "", "MeshRenderer", {"mesh", "materialOverride"}}},
            };
            return classes;
        }

        const Names &transformFields(const std::string &transform)
        {
            static const Names none;
            return transform == "Transform2D" ? s_transform2D : transform == "Transform3D" ? s_transform3D : transform == "RectTransform" ? s_rectTransform : none;
        }

        struct Resolved
        {
            std::string m_transform;
            std::string m_component;
            Names m_componentFields;
            std::string m_game;
        };

        struct Context
        {
            std::map<std::string, std::string> m_gameParents;
            std::map<std::string, std::string> m_sceneRoots;
            std::string m_file;
            int m_warnings = 0;
        };

        void warn(Context &context, const std::string &message)
        {
            std::cerr << "fried_import: " << context.m_file << ": " << message << "\n";
            context.m_warnings++;
        }

        bool resolve(Context &context, const std::string &type, Resolved *resolved)
        {
            std::string current = type;
            if (!engineClasses().count(current))
            {
                resolved->m_game = current;
            }
            int guard = 0;
            while (!current.empty() && guard++ < 64)
            {
                auto engine = engineClasses().find(current);
                if (engine != engineClasses().end())
                {
                    if (resolved->m_transform.empty())
                    {
                        resolved->m_transform = engine->second.m_transform;
                    }
                    if (resolved->m_component.empty() && !engine->second.m_component.empty())
                    {
                        resolved->m_component = engine->second.m_component;
                        resolved->m_componentFields = engine->second.m_fields;
                    }
                    current = engine->second.m_parent;
                    continue;
                }
                auto game = context.m_gameParents.find(current);
                if (game == context.m_gameParents.end())
                {
                    return false;
                }
                current = game->second;
            }
            return true;
        }

        Value text(const std::string &string)
        {
            Value value;
            value.m_kind = Value::Kind::String;
            value.m_string = string;
            return value;
        }

        Value object()
        {
            Value value;
            value.m_kind = Value::Kind::Object;
            return value;
        }

        Value array()
        {
            Value value;
            value.m_kind = Value::Kind::Array;
            return value;
        }

        Value boolean(bool state)
        {
            Value value;
            value.m_kind = Value::Kind::Bool;
            value.m_bool = state;
            return value;
        }

        Value integer(int number)
        {
            Value value;
            value.m_kind = Value::Kind::Number;
            value.m_number = number;
            value.m_isInteger = true;
            return value;
        }

        struct Routed
        {
            Value m_transform = object();
            Value m_engine = object();
            Value m_game = object();
            bool m_hasActive = false;
            bool m_active = true;
        };

        Routed route(Context &context, const Resolved &resolved, const Value &node, const std::string &id)
        {
            Routed routed;
            const Names &placed = transformFields(resolved.m_transform);
            bool hasEngine = !resolved.m_component.empty();
            bool engineIsDrawn = hasEngine && s_drawn.count(resolved.m_component) > 0;
            for (const auto &pair : node.m_object)
            {
                const std::string &key = pair.first;
                if (key == "type" || key == "id" || key == "name" || key == "children" || key == "instance")
                {
                    continue;
                }
                if (key == "active")
                {
                    routed.m_hasActive = true;
                    routed.m_active = pair.second.m_bool;
                    continue;
                }
                if (placed.count(key))
                {
                    routed.m_transform.m_object[key] = pair.second;
                }
                else if (key == "visible")
                {
                    Value *target = hasEngine ? &routed.m_engine : resolved.m_game.empty() ? nullptr : &routed.m_game;
                    if (target != nullptr)
                    {
                        target->m_object["enabled"] = pair.second;
                    }
                    else
                    {
                        warn(context, "the object " + id + " is hidden with visible, which has nothing to switch off now, so it was dropped");
                    }
                }
                else if (key == "priority")
                {
                    Value *target = engineIsDrawn ? &routed.m_engine : resolved.m_game.empty() ? nullptr : &routed.m_game;
                    if (target != nullptr)
                    {
                        target->m_object[key] = pair.second;
                    }
                    else
                    {
                        warn(context, "the object " + id + " has a priority, which its components do not draw with, so it was dropped");
                    }
                }
                else if (resolved.m_componentFields.count(key))
                {
                    routed.m_engine.m_object[key] = pair.second;
                }
                else if (!resolved.m_game.empty())
                {
                    routed.m_game.m_object[key] = pair.second;
                }
                else
                {
                    warn(context, "the field " + key + " of the object " + id + " belongs to no component, so it was dropped");
                }
            }
            return routed;
        }

        void addDefaults(const Resolved &resolved, Routed *routed)
        {
            double width = 0;
            double height = 0;
            if (resolved.m_component == "Button")
            {
                width = 100;
                height = 30;
            }
            else if (resolved.m_component == "TouchButton")
            {
                width = 80;
                height = 80;
            }
            else if (resolved.m_component == "VirtualJoystick")
            {
                width = 200;
                height = 200;
            }
            else
            {
                return;
            }
            if (!routed->m_transform.find("width"))
            {
                routed->m_transform.m_object["width"] = integer((int)width);
            }
            if (!routed->m_transform.find("height"))
            {
                routed->m_transform.m_object["height"] = integer((int)height);
            }
        }

        Value withType(const std::string &type, const Value &fields)
        {
            Value result = fields;
            result.m_object["type"] = text(type);
            return result;
        }

        Value convertNode(Context &context, const Value &node)
        {
            Value result = object();
            const Value *idValue = node.find("id");
            std::string id = idValue != nullptr ? idValue->m_string : "";
            result.m_object["id"] = text(id);
            if (const Value *name = node.find("name"))
            {
                result.m_object["name"] = *name;
            }

            const Value *instance = node.find("instance");
            std::string typeName;
            if (instance != nullptr)
            {
                auto root = context.m_sceneRoots.find(instance->m_string);
                if (root == context.m_sceneRoots.end())
                {
                    warn(context, "the instance " + id + " names the scene " + instance->m_string + ", which this project does not have, so its overrides were kept as they are");
                    return node;
                }
                typeName = root->second;
                result.m_object["instance"] = *instance;
            }
            else
            {
                const Value *type = node.find("type");
                typeName = type != nullptr ? type->m_string : "Node";
            }

            Resolved resolved;
            if (!resolve(context, typeName, &resolved))
            {
                warn(context, "the object " + id + " has the type " + typeName + ", whose class was not found in src, so it was kept as a plain object");
                resolved = Resolved();
            }
            Routed routed = route(context, resolved, node, id);
            if (instance == nullptr)
            {
                addDefaults(resolved, &routed);
            }
            if (routed.m_hasActive)
            {
                result.m_object["active"] = boolean(routed.m_active);
            }

            if (instance == nullptr)
            {
                if (!resolved.m_transform.empty())
                {
                    result.m_object["transform"] = withType(resolved.m_transform, routed.m_transform);
                }
                Value components = array();
                if (!resolved.m_component.empty())
                {
                    components.m_array.push_back(withType(resolved.m_component, routed.m_engine));
                }
                if (!resolved.m_game.empty())
                {
                    components.m_array.push_back(withType(resolved.m_game, routed.m_game));
                }
                if (!components.m_array.empty())
                {
                    result.m_object["components"] = components;
                }
            }
            else
            {
                if (!routed.m_transform.m_object.empty())
                {
                    result.m_object["transform"] = routed.m_transform;
                }
                Value components = array();
                if (!resolved.m_component.empty() && !routed.m_engine.m_object.empty())
                {
                    components.m_array.push_back(withType(resolved.m_component, routed.m_engine));
                }
                if (!resolved.m_game.empty() && !routed.m_game.m_object.empty())
                {
                    components.m_array.push_back(withType(resolved.m_game, routed.m_game));
                }
                if (!components.m_array.empty())
                {
                    result.m_object["components"] = components;
                }
            }

            if (const Value *children = node.find("children"))
            {
                Value converted = array();
                for (const Value &child : children->m_array)
                {
                    converted.m_array.push_back(convertNode(context, child));
                }
                result.m_object["children"] = converted;
            }
            return result;
        }

        std::string number(const Value &value)
        {
            if (value.m_isInteger)
            {
                return std::to_string((long long)value.m_number);
            }
            char buffer[64];
            for (int precision = 1; precision <= 17; precision++)
            {
                std::snprintf(buffer, sizeof(buffer), "%.*g", precision, value.m_number);
                if (std::strtod(buffer, nullptr) == value.m_number)
                {
                    break;
                }
            }
            return buffer;
        }

        bool isPlain(const std::string &string)
        {
            if (string.empty() || string == "true" || string == "false" || string == "null" || string == "~" || string == "yes" || string == "no")
            {
                return false;
            }
            char *end = nullptr;
            std::strtod(string.c_str(), &end);
            if (end != nullptr && *end == '\0')
            {
                return false;
            }
            if (string.front() == ' ' || string.back() == ' ')
            {
                return false;
            }
            for (char character : string)
            {
                bool allowed = std::isalnum((unsigned char)character) || character == '_' || character == '.' || character == '/' || character == '-' || character == ' ' || character == '@' || character == '+';
                if (!allowed)
                {
                    return false;
                }
            }
            return string.front() != '-' && string.front() != '@' && string.front() != '+';
        }

        std::string quoted(const std::string &string)
        {
            std::string result = "\"";
            for (char character : string)
            {
                switch (character)
                {
                case '"':
                    result += "\\\"";
                    break;
                case '\\':
                    result += "\\\\";
                    break;
                case '\n':
                    result += "\\n";
                    break;
                case '\t':
                    result += "\\t";
                    break;
                case '\r':
                    result += "\\r";
                    break;
                default:
                    result += character;
                }
            }
            return result + "\"";
        }

        std::string scalar(const Value &value)
        {
            switch (value.m_kind)
            {
            case Value::Kind::Null:
                return "null";
            case Value::Kind::Bool:
                return value.m_bool ? "true" : "false";
            case Value::Kind::Number:
                return number(value);
            case Value::Kind::String:
                return isPlain(value.m_string) ? value.m_string : quoted(value.m_string);
            default:
                return "";
            }
        }

        bool isScalar(const Value &value)
        {
            return value.m_kind != Value::Kind::Array && value.m_kind != Value::Kind::Object;
        }

        bool isFlat(const Value &value)
        {
            if (value.m_kind != Value::Kind::Object)
            {
                return false;
            }
            for (const auto &pair : value.m_object)
            {
                if (!isScalar(pair.second))
                {
                    return false;
                }
            }
            return true;
        }

        std::vector<std::string> orderedKeys(const Value &value, bool flow)
        {
            static const std::vector<std::string> flowFirst = {"type", "r", "g", "b", "a", "root", "path", "size", "x", "y"};
            static const std::vector<std::string> blockFirst = {"version", "type", "id", "name", "camera", "objects", "active", "instance", "transform", "components"};
            std::vector<std::string> keys;
            const std::vector<std::string> &first = flow ? flowFirst : blockFirst;
            for (const std::string &key : first)
            {
                if (value.m_object.count(key))
                {
                    keys.push_back(key);
                }
            }
            for (const auto &pair : value.m_object)
            {
                if (std::find(keys.begin(), keys.end(), pair.first) == keys.end() && pair.first != "children")
                {
                    keys.push_back(pair.first);
                }
            }
            if (!flow && value.m_object.count("children"))
            {
                keys.push_back("children");
            }
            return keys;
        }

        std::string keyText(const std::string &key)
        {
            return isPlain(key) ? key : quoted(key);
        }

        std::string flow(const Value &value)
        {
            if (isScalar(value))
            {
                return scalar(value);
            }
            std::string result = "{";
            bool first = true;
            for (const std::string &key : orderedKeys(value, true))
            {
                result += (first ? "" : ", ") + keyText(key) + ": " + scalar(value.m_object.at(key));
                first = false;
            }
            return result + "}";
        }

        void emit(const Value &value, int indent, std::string *out);

        void emitMember(const std::string &key, const Value &value, int indent, std::string *out)
        {
            std::string pad(indent, ' ');
            if (isScalar(value) || isFlat(value))
            {
                if (value.m_kind == Value::Kind::Object && value.m_object.empty())
                {
                    *out += pad + keyText(key) + ": {}\n";
                }
                else
                {
                    *out += pad + keyText(key) + ": " + flow(value) + "\n";
                }
                return;
            }
            if (value.m_kind == Value::Kind::Array && value.m_array.empty())
            {
                *out += pad + keyText(key) + ": []\n";
                return;
            }
            *out += pad + keyText(key) + ":\n";
            emit(value, value.m_kind == Value::Kind::Array ? indent + 2 : indent + 2, out);
        }

        void emit(const Value &value, int indent, std::string *out)
        {
            std::string pad(indent, ' ');
            if (value.m_kind == Value::Kind::Array)
            {
                for (const Value &item : value.m_array)
                {
                    if (isScalar(item))
                    {
                        *out += pad + "- " + scalar(item) + "\n";
                        continue;
                    }
                    std::string inner;
                    emit(item, indent + 2, &inner);
                    *out += pad + "- " + inner.substr(indent + 2);
                }
                return;
            }
            for (const std::string &key : orderedKeys(value, false))
            {
                emitMember(key, value.m_object.at(key), indent, out);
            }
        }

        bool readFile(const fs::path &path, std::string *text)
        {
            std::ifstream stream(path, std::ios::binary);
            if (!stream)
            {
                return false;
            }
            std::stringstream buffer;
            buffer << stream.rdbuf();
            *text = buffer.str();
            return true;
        }

        std::string sceneNameOf(const fs::path &path)
        {
            std::string file = path.filename().string();
            for (const char *suffix : {".scene.yaml", ".scene.json"})
            {
                std::string tail = suffix;
                if (file.size() > tail.size() && file.compare(file.size() - tail.size(), tail.size(), tail) == 0)
                {
                    return file.substr(0, file.size() - tail.size());
                }
            }
            return "";
        }

        void collectClasses(Context &context, const fs::path &source)
        {
            static const std::regex declaration("class\\s+(\\w+)\\s+extends\\s+([\\w.]+)");
            if (!fs::exists(source))
            {
                return;
            }
            for (const auto &entry : fs::recursive_directory_iterator(source))
            {
                if (!entry.is_regular_file() || entry.path().extension() != ".hx")
                {
                    continue;
                }
                std::string text;
                if (!readFile(entry.path(), &text))
                {
                    continue;
                }
                for (std::sregex_iterator match(text.begin(), text.end(), declaration), end; match != end; ++match)
                {
                    std::string parent = (*match)[2];
                    size_t dot = parent.rfind('.');
                    context.m_gameParents[(*match)[1]] = dot == std::string::npos ? parent : parent.substr(dot + 1);
                }
            }
        }
    }

    int runMigrateScenes(const char *projectDirectory)
    {
        fs::path project = projectDirectory;
        Context context;
        collectClasses(context, project / "src");

        struct SceneFile
        {
            fs::path m_path;
            Value m_value;
        };
        std::vector<SceneFile> files;
        fs::path assets = project / "assets";
        if (!fs::exists(assets))
        {
            std::cerr << "fried_import: " << assets.string() << " does not exist\n";
            return 1;
        }
        for (const auto &entry : fs::recursive_directory_iterator(assets))
        {
            std::string name = entry.is_regular_file() ? sceneNameOf(entry.path()) : "";
            if (name.empty())
            {
                continue;
            }
            std::string text;
            SceneFile file;
            std::string error;
            if (!readFile(entry.path(), &text) || !parseYaml(text, &file.m_value, &error))
            {
                std::cerr << "fried_import: " << entry.path().string() << ":" << error << "\n";
                return 1;
            }
            file.m_path = entry.path();
            const Value *version = file.m_value.find("version");
            const Value *nodes = file.m_value.find("nodes");
            if (version != nullptr && version->m_number == 2 && nodes != nullptr && nodes->m_array.size() == 1)
            {
                const Value *type = nodes->m_array[0].find("type");
                if (type != nullptr)
                {
                    context.m_sceneRoots[name] = type->m_string;
                }
            }
            files.push_back(file);
        }

        int migrated = 0;
        for (SceneFile &file : files)
        {
            const Value *version = file.m_value.find("version");
            const Value *nodes = file.m_value.find("nodes");
            if (version == nullptr || version->m_number != 2 || nodes == nullptr)
            {
                continue;
            }
            context.m_file = fs::relative(file.m_path, project).string();
            Value converted = object();
            converted.m_object["version"] = integer(3);
            if (const Value *name = file.m_value.find("name"))
            {
                converted.m_object["name"] = *name;
            }
            if (const Value *camera = file.m_value.find("camera"))
            {
                converted.m_object["camera"] = *camera;
            }
            Value objects = array();
            for (const Value &node : nodes->m_array)
            {
                objects.m_array.push_back(convertNode(context, node));
            }
            converted.m_object["objects"] = objects;

            fs::path backup = project / ".fried" / "v2-backup" / fs::relative(file.m_path, project);
            fs::create_directories(backup.parent_path());
            fs::copy_file(file.m_path, backup, fs::copy_options::overwrite_existing);
            std::string output;
            if (file.m_path.extension() == ".json")
            {
                output = toJson(converted) + "\n";
            }
            else
            {
                emit(converted, 0, &output);
            }
            std::ofstream stream(file.m_path, std::ios::binary | std::ios::trunc);
            stream << output;
            std::cout << "migrated " << context.m_file << "\n";
            migrated++;
        }
        std::cout << migrated << " scene files migrated, " << context.m_warnings << " warnings. The originals are in .fried/v2-backup.\n";
        return 0;
    }
}
