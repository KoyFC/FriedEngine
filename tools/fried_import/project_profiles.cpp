#include "project_profiles.h"

#include <algorithm>
#include <array>
#include <map>
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

        std::string names(const std::map<std::string, Value> &entries)
        {
            std::string list;
            for (const auto &entry : entries)
            {
                list += list.empty() ? "" : ", ";
                list += entry.first;
            }
            return list;
        }

        bool runsOn(const Value &backend, const std::string &platform)
        {
            const Value *platforms = backend.find("platforms");
            if (platforms == nullptr || (platforms->m_kind == Value::Kind::String && platforms->m_string == "all"))
            {
                return true;
            }
            for (const Value &name : platforms->m_array)
            {
                if (name.m_string == platform)
                {
                    return true;
                }
            }
            return false;
        }

        // Finds the backend a project names for a module, or sets the error with the place it was named at.
        const Value *chosenBackend(const Value &module, const std::string &backendName, const std::string &place, std::string *error)
        {
            const Value *backends = module.find("backends");
            const Value *backend = backends == nullptr ? nullptr : backends->find(backendName);
            if (backend == nullptr)
            {
                *error = "project.fried gives \"" + place + "\" the backend \"" + backendName + "\", which is not one of: " + names(backends->m_object) + ".";
                return nullptr;
            }
            const Value *planned = backend->find("planned");
            if (planned != nullptr && planned->m_bool)
            {
                *error = "project.fried gives \"" + place + "\" the backend \"" + backendName + "\", which is planned and cannot be chosen yet.";
                return nullptr;
            }
            return backend;
        }

        bool readChoices(const Value *modules, const Value &manifest, const std::string &place, std::map<std::string, std::string> *choices, std::string *error)
        {
            if (modules == nullptr)
            {
                return true;
            }
            if (modules->m_kind != Value::Kind::Object)
            {
                *error = "project.fried gives \"" + place + "\" as something other than a map of module names to backends.";
                return false;
            }
            for (const auto &[name, backend] : modules->m_object)
            {
                const Value *module = manifest.find(name);
                if (module == nullptr)
                {
                    *error = "project.fried gives \"" + place + "\" the module \"" + name + "\", which is not one of: " + names(manifest.m_object) + ".";
                    return false;
                }
                if (backend.m_kind != Value::Kind::String || chosenBackend(*module, backend.m_string, place + "." + name, error) == nullptr)
                {
                    if (error->empty())
                    {
                        *error = "project.fried gives \"" + place + "." + name + "\" as something other than a backend name.";
                    }
                    return false;
                }
                (*choices)[name] = backend.m_string;
            }
            return true;
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

namespace fried_import
{
    bool resolveModules(Value *project, const Value &manifest, std::string *error)
    {
        std::map<std::string, std::string> shared;
        if (!readChoices(project->find("modules"), manifest, "modules", &shared, error))
        {
            return false;
        }

        Value &profiles = project->m_object["platforms"];
        for (auto &[platform, profile] : profiles.m_object)
        {
            std::map<std::string, std::string> own;
            if (!readChoices(profile.find("modules"), manifest, "platforms." + platform + ".modules", &own, error))
            {
                return false;
            }

            Value resolved;
            resolved.m_kind = Value::Kind::Object;
            for (const auto &[moduleName, module] : manifest.m_object)
            {
                std::string backendName = module.find("default")->m_string;
                bool isOwn = own.count(moduleName) > 0;
                if (isOwn)
                {
                    backendName = own[moduleName];
                }
                else if (shared.count(moduleName) > 0)
                {
                    backendName = shared[moduleName];
                }

                if (!isOwn && !runsOn(*module.find("backends")->find(backendName), platform))
                {
                    backendName = module.find("default")->m_string;
                }
                const Value &backend = *module.find("backends")->find(backendName);
                if (!runsOn(backend, platform))
                {
                    std::string fallback = module.find("default")->m_string;
                    *error = "project.fried: " + moduleName + ": " + backendName + " does not run on " + platform + ". Set \"platforms." + platform + ".modules." + moduleName + "\" to " + fallback + ".";
                    return false;
                }
                Value name;
                name.m_kind = Value::Kind::String;
                name.m_string = backendName;
                resolved.m_object[moduleName] = name;
            }
            profile.m_object["modules"] = resolved;
        }
        return true;
    }
}
