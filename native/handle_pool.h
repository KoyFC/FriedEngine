#pragma once

#include <vector>

template <typename T>
class HandlePool
{
public:
    int store(T *resource)
    {
        if (!resource)
        {
            return -1;
        }

        if (!m_freeIds.empty())
        {
            int id = m_freeIds.back();
            m_freeIds.pop_back();
            m_resources[id] = resource;
            return id;
        }

        m_resources.push_back(resource);
        return (int)(m_resources.size() - 1);
    }

    T *get(int id) const
    {
        if (id < 0 || id >= (int)m_resources.size())
        {
            return nullptr;
        }
        return m_resources[id];
    }

    T *release(int id)
    {
        T *resource = get(id);
        if (!resource)
        {
            return nullptr;
        }

        m_resources[id] = nullptr;
        m_freeIds.push_back(id);
        return resource;
    }

    int capacity() const
    {
        return (int)m_resources.size();
    }

    int count() const
    {
        return (int)(m_resources.size() - m_freeIds.size());
    }

private:
    std::vector<T *> m_resources;
    std::vector<int> m_freeIds;
};
