#include "scene/tilemap.h"

#include <stdlib.h>

#include <vector>

namespace
{
    std::vector<FriedTilemap *> s_maps;
    std::vector<int> s_freeIds;
    std::vector<int> s_solidRects;

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

    int fried_tilemap_build_solid(int id)
    {
        s_solidRects.clear();
        const FriedTilemap *map = lookup(id);
        if (map == nullptr)
        {
            return 0;
        }
        const int width = map->m_width;
        const int height = map->m_height;
        std::vector<uint8_t> taken((size_t)width * (size_t)height, 0);
        for (int row = 0; row < height; ++row)
        {
            for (int column = 0; column < width; ++column)
            {
                if (map->m_cells[row * width + column] == 0 || taken[row * width + column])
                {
                    continue;
                }
                int runEnd = column + 1;
                while (runEnd < width && map->m_cells[row * width + runEnd] != 0 && !taken[row * width + runEnd])
                {
                    ++runEnd;
                }
                int rowEnd = row + 1;
                for (; rowEnd < height; ++rowEnd)
                {
                    bool isWholeRun = true;
                    for (int at = column; at < runEnd; ++at)
                    {
                        if (map->m_cells[rowEnd * width + at] == 0 || taken[rowEnd * width + at])
                        {
                            isWholeRun = false;
                            break;
                        }
                    }
                    if (!isWholeRun)
                    {
                        break;
                    }
                }
                for (int at = row; at < rowEnd; ++at)
                {
                    for (int across = column; across < runEnd; ++across)
                    {
                        taken[at * width + across] = 1;
                    }
                }
                s_solidRects.push_back(column);
                s_solidRects.push_back(row);
                s_solidRects.push_back(runEnd - column);
                s_solidRects.push_back(rowEnd - row);
            }
        }
        return (int)(s_solidRects.size() / 4);
    }

    void fried_tilemap_solid_rect(int index, int *out)
    {
        if (index < 0 || (size_t)index * 4 + 3 >= s_solidRects.size())
        {
            out[0] = out[1] = out[2] = out[3] = 0;
            return;
        }
        for (int part = 0; part < 4; ++part)
        {
            out[part] = s_solidRects[(size_t)index * 4 + part];
        }
    }
}
