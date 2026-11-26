#include "scene/tilemap.h"

#include <stdlib.h>

#include <vector>

namespace
{
    std::vector<FriedTilemap *> s_maps;
    std::vector<int> s_freeIds;

    FriedTilemap *lookup(int id)
    {
        return id >= 0 && id < (int)s_maps.size() ? s_maps[id] : nullptr;
    }
}

const FriedTilemap *fried_tilemap_get(int id)
{
    return lookup(id);
}

extern "C"
{
    int fried_tilemap_create(int width, int height, int tileWidth, int tileHeight, int columns)
    {
        if (width <= 0 || height <= 0 || tileWidth <= 0 || tileHeight <= 0 || columns <= 0)
        {
            return -1;
        }
        uint16_t *cells = (uint16_t *)calloc((size_t)width * (size_t)height, sizeof(uint16_t));
        FriedTilemap *map = (FriedTilemap *)malloc(sizeof(FriedTilemap));
        if (cells == nullptr || map == nullptr)
        {
            free(cells);
            free(map);
            return -1;
        }
        *map = {width, height, tileWidth, tileHeight, columns, cells};
        if (!s_freeIds.empty())
        {
            int id = s_freeIds.back();
            s_freeIds.pop_back();
            s_maps[id] = map;
            return id;
        }
        s_maps.push_back(map);
        return (int)s_maps.size() - 1;
    }

    void fried_tilemap_release(int id)
    {
        FriedTilemap *map = lookup(id);
        if (map == nullptr)
        {
            return;
        }
        free(map->m_cells);
        free(map);
        s_maps[id] = nullptr;
        s_freeIds.push_back(id);
    }

    void fried_tilemap_set_cell(int id, int x, int y, int value)
    {
        FriedTilemap *map = lookup(id);
        if (map != nullptr && x >= 0 && y >= 0 && x < map->m_width && y < map->m_height)
        {
            map->m_cells[y * map->m_width + x] = (uint16_t)value;
        }
    }

    int fried_tilemap_get_cell(int id, int x, int y)
    {
        const FriedTilemap *map = lookup(id);
        return map != nullptr && x >= 0 && y >= 0 && x < map->m_width && y < map->m_height ? map->m_cells[y * map->m_width + x] : 0;
    }
}
