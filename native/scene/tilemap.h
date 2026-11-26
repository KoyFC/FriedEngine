#pragma once

#include <stdint.h>

// A grid of tiles, each a cell of a tileset texture, whose cells live here so that drawing a map walks an array of integers and never makes an object for a tile.
struct FriedTilemap
{
    int m_width;
    int m_height;
    int m_tileWidth;
    int m_tileHeight;
    // The tiles in a row of the tileset texture.
    int m_columns;
    // A cell holds 0 for no tile, or the tile's place in the tileset plus one, counting along the rows.
    uint16_t *m_cells;
};

extern "C"
{
    // Returns the map's id, or -1 when it does not fit in memory.
    int fried_tilemap_create(int width, int height, int tileWidth, int tileHeight, int columns);
    void fried_tilemap_release(int id);
    void fried_tilemap_set_cell(int id, int x, int y, int value);
    int fried_tilemap_get_cell(int id, int x, int y);
    // Covers the map's non-empty cells with as few rectangles as a greedy pass finds (a run along a row, grown down while the rows below hold the same run) and returns how many. They stay readable until the next call.
    int fried_tilemap_build_solid(int id);
    // A rectangle of the last fried_tilemap_build_solid() as left, top, width and height in cells.
    void fried_tilemap_solid_rect(int index, int *out);
}

const FriedTilemap *fried_tilemap_get(int id);
