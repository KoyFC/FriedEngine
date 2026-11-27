#pragma once

#include <map>
#include <string>
#include <vector>

namespace fried_import
{
    struct Value
    {
        enum class Kind
        {
            Null,
            Bool,
            Number,
            String,
            Array,
            Object
        };
        Kind m_kind = Kind::Null;
        bool m_bool = false;
        double m_number = 0;
        bool m_isInteger = false;
        std::string m_string;
        std::vector<Value> m_array;
        std::map<std::string, Value> m_object;

        const Value *find(const std::string &key) const
        {
            auto found = m_object.find(key);
            return m_kind == Kind::Object && found != m_object.end() ? &found->second : nullptr;
        }
    };
}
