#include "modules.h"

#include "yaml.h"

#include <fstream>
#include <map>
#include <sstream>

namespace fried_import
{
    namespace
    {
        bool readValue(const std::string &path, Value *value, std::string *error)
        {
            std::ifstream stream(path, std::ios::binary);
            if (!stream)
            {
                *error = "cannot read " + path;
                return false;
            }
            std::stringstream text;
            text << stream.rdbuf();
            if (!parseYaml(text.str(), value, error))
            {
                *error = path + ":" + *error;
                return false;
            }
            return true;
        }

        void removeFromObject(Value *object, const ModuleFilter &filter, std::map<std::string, int> *counts)
        {
            if (object->m_kind != Value::Kind::Object)
            {
                return;
            }
            auto components = object->m_object.find("components");
            if (components != object->m_object.end() && components->second.m_kind == Value::Kind::Array)
            {
                std::vector<Value> kept;
                for (Value &component : components->second.m_array)
                {
                    const Value *type = component.find("type");
                    std::string owner = type != nullptr && type->m_kind == Value::Kind::String ? filter.leavesOutComponent(type->m_string) : std::string();
                    if (owner.empty())
                    {
                        kept.push_back(std::move(component));
                    }
                    else
                    {
                        ++(*counts)[owner];
                    }
                }
                components->second.m_array = std::move(kept);
            }
            auto children = object->m_object.find("children");
            if (children != object->m_object.end() && children->second.m_kind == Value::Kind::Array)
            {
                for (Value &child : children->second.m_array)
                {
                    removeFromObject(&child, filter, counts);
                }
            }
        }
    }

    bool ModuleFilter::load(const std::string &platform, const std::string &manifestPath, const std::string &activePath, std::string *error)
    {
        Value manifest, active;
        if (!readValue(manifestPath, &manifest, error) || !readValue(activePath, &active, error))
        {
            return false;
        }
        m_platform = platform;
        m_rules.clear();
        const Value *chosen = active.find("active");
        for (const auto &[moduleName, module] : manifest.m_object)
        {
            const Value *chosenName = chosen == nullptr ? nullptr : chosen->find(moduleName);
            const Value *backends = module.find("backends");
            if (backends == nullptr)
            {
                continue;
            }
            for (const auto &[backendName, backend] : backends->m_object)
            {
                bool isUsed = chosenName != nullptr && chosenName->m_string == backendName;
                const Value *degraded = backend.find("degraded");
                bool isDegraded = isUsed && degraded != nullptr && degraded->find(platform) != nullptr;
                if (isUsed && !isDegraded)
                {
                    continue;
                }

                Rule rule;
                rule.m_label = moduleName + ": " + backendName;
                const Value *components = backend.find("components");
                if (components != nullptr)
                {
                    for (const Value &name : components->m_array)
                    {
                        rule.m_components.insert(name.m_string);
                    }
                }
                const Value *assets = backend.find("dropAssets");
                if (isDegraded && assets != nullptr)
                {
                    rule.m_hasAssets = true;
                    rule.m_assets = std::regex(assets->m_string, std::regex::icase | std::regex::ECMAScript);
                }
                if (!rule.m_components.empty() || rule.m_hasAssets)
                {
                    m_rules.push_back(std::move(rule));
                }
            }
        }
        return true;
    }

    std::string ModuleFilter::leavesOutComponent(const std::string &type) const
    {
        for (const Rule &rule : m_rules)
        {
            if (rule.m_components.count(type) > 0)
            {
                return rule.m_label;
            }
        }
        return std::string();
    }

    std::string ModuleFilter::leavesOutAsset(const std::string &relativePath) const
    {
        for (const Rule &rule : m_rules)
        {
            if (rule.m_hasAssets && std::regex_search(relativePath, rule.m_assets))
            {
                return rule.m_label;
            }
        }
        return std::string();
    }

    void removeLeftOutComponents(Value *scene, const ModuleFilter &filter, std::map<std::string, int> *counts)
    {
        auto objects = scene->m_object.find("objects");
        if (scene->m_kind != Value::Kind::Object || objects == scene->m_object.end() || objects->second.m_kind != Value::Kind::Array)
        {
            return;
        }
        for (Value &object : objects->second.m_array)
        {
            removeFromObject(&object, filter, counts);
        }
    }
}
