#pragma once

#include "value.h"

#include <regex>
#include <set>
#include <string>
#include <vector>

namespace fried_import
{
    // What the modules a project uses on one platform leave out of its assets: the components of a backend the platform does not use, and the files of a backend that runs on it with less.
    class ModuleFilter
    {
    public:
        // Reads modules.json and the backend each module has on this platform. Nothing is left out until it has been loaded.
        bool load(const std::string &platform, const std::string &manifestPath, const std::string &activePath, std::string *error);

        // The "module: backend" a component of this type belongs to when it is left out, or an empty string when it stays.
        std::string leavesOutComponent(const std::string &type) const;

        // The "module: backend" that leaves a file out, or an empty string when it stays. The path is relative to the asset root.
        std::string leavesOutAsset(const std::string &relativePath) const;

        const std::string &platform() const
        {
            return m_platform;
        }

    private:
        struct Rule
        {
            std::string m_label;
            std::set<std::string> m_components;
            bool m_hasAssets = false;
            std::regex m_assets;
        };

        std::string m_platform;
        std::vector<Rule> m_rules;
    };

    // Takes out of a scene the components the filter leaves out, in every object and in the overrides of an instance, and counts them by the "module: backend" that left each out.
    void removeLeftOutComponents(Value *scene, const ModuleFilter &filter, std::map<std::string, int> *counts);
}
