#include "project_profiles.h"

#include <algorithm>
#include <array>
#include <string_view>

namespace fried_import
{
    namespace
    {
        constexpr std::array<std::string_view, 8> s_platforms = {"pc", "vita", "switch", "3ds", "nds", "cg50", "web", "android"};

        bool isPlatform(const std::string &name)
        {
            return std::find(s_platforms.begin(), s_platforms.end(), name) != s_platforms.end();
        }

        Value emptyObject()
        {
            Value value;
            value.m_kind = Value::Kind::Object;
            return value;
        }

        std::string platformList()
        {
            std::string list;
            for (std::string_view name : s_platforms)
            {
                list += list.empty() ? "" : ", ";
                list += name;
            }
            return list;
        }
    }

    bool normalizeProfiles(Value *project, std::string *error)
    {
        bool isOldLayout = false;
        Value profiles = emptyObject();
        bool isDeclared = false;

        auto declared = project->m_object.find("platforms");
        if (declared != project->m_object.end())
        {
            isDeclared = true;
            if (declared->second.m_kind == Value::Kind::Array)
            {
                isOldLayout = true;
                for (const Value &name : declared->second.m_array)
                {
                    if (name.m_kind != Value::Kind::String || !isPlatform(name.m_string))
                    {
                        *error = "project.fried declares the platform \"" + name.m_string + "\", which is not one of: " + platformList() + ".";
                        return false;
                    }
                    profiles.m_object[name.m_string] = emptyObject();
                }
            }
            else if (declared->second.m_kind == Value::Kind::Object)
            {
                for (const auto &[name, profile] : declared->second.m_object)
                {
                    if (!isPlatform(name))
                    {
                        *error = "project.fried declares the platform \"" + name + "\", which is not one of: " + platformList() + ".";
                        return false;
                    }
                    if (profile.m_kind != Value::Kind::Object && profile.m_kind != Value::Kind::Null)
                    {
                        *error = "project.fried declares \"platforms." + name + "\" as something other than a map of settings.";
                        return false;
                    }
                    profiles.m_object[name] = profile.m_kind == Value::Kind::Object ? profile : emptyObject();
                }
            }
            else
            {
                *error = "project.fried declares \"platforms\" as something other than a map of platforms. Use a map with entries from: " + platformList() + ".";
                return false;
            }
        }

        for (std::string_view name : s_platforms)
        {
            auto section = project->m_object.find(std::string(name));
            if (section == project->m_object.end())
            {
                continue;
            }
            isOldLayout = true;
            if (section->second.m_kind == Value::Kind::Object)
            {
                if (!isDeclared)
                {
                    profiles.m_object[std::string(name)] = emptyObject();
                }
                auto profile = profiles.m_object.find(std::string(name));
                if (profile != profiles.m_object.end())
                {
                    for (const auto &[key, value] : section->second.m_object)
                    {
                        profile->second.m_object.emplace(key, value);
                    }
                }
            }
            project->m_object.erase(section);
        }

        if (!isDeclared)
        {
            for (std::string_view name : s_platforms)
            {
                profiles.m_object.emplace(std::string(name), emptyObject());
            }
        }

        project->m_object["platforms"] = profiles;
        return isOldLayout;
    }
}
