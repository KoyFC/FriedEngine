#include "physics/collider_store.h"

#include <algorithm>
#include <cstdint>
#include <vector>

#include "handle_pool.h"

namespace
{
    // 64 pixels, in the 20.12 units of a box.
    constexpr int s_cellShift = 18;
    constexpr int s_bucketCount = 256;
    constexpr int s_bucketMask = s_bucketCount - 1;

    // A box or a query that spans more cells than this is not looked up by cell: a collider that big is a candidate of every query, and a query that big has every collider as one.
    constexpr int s_maxCells = 16;

    struct Entry
    {
        int m_left;
        int m_top;
        int m_right;
        int m_bottom;
        int m_cellMinX;
        int m_cellMinY;
        int m_cellMaxX;
        int m_cellMaxY;
        int m_stamp;
        bool m_isInGrid;
        bool m_isLarge;
    };

    // The cells are hashed into a fixed number of buckets, so the world has no edge. Two cells in one bucket only add a candidate the caller's own test turns away.
    struct Store
    {
        std::vector<Entry> m_entries;
        std::vector<int> m_buckets[s_bucketCount];
        std::vector<int> m_large;
        int m_stamp = 0;
    };

    HandlePool<Store> s_stores;

    int bucketOf(int cellX, int cellY)
    {
        return (int)((((uint32_t)cellX * 7919u) ^ ((uint32_t)cellY * 104729u)) & (uint32_t)s_bucketMask);
    }

    // Without keeping the order, which nothing depends on.
    void take(std::vector<int> &list, int index)
    {
        for (size_t position = 0; position < list.size(); ++position)
        {
            if (list[position] == index)
            {
                list[position] = list.back();
                list.pop_back();
                return;
            }
        }
    }

    void remove(Store &store, int index)
    {
        const Entry &entry = store.m_entries[index];
        if (entry.m_isLarge)
        {
            take(store.m_large, index);
            return;
        }
        for (int cellY = entry.m_cellMinY; cellY <= entry.m_cellMaxY; ++cellY)
        {
            for (int cellX = entry.m_cellMinX; cellX <= entry.m_cellMaxX; ++cellX)
            {
                take(store.m_buckets[bucketOf(cellX, cellY)], index);
            }
        }
    }

    struct Cells
    {
        int m_minX;
        int m_minY;
        int m_maxX;
        int m_maxY;
    };

    Cells cellsOf(int left, int top, int right, int bottom)
    {
        Cells cells = {left >> s_cellShift, top >> s_cellShift, (right - 1) >> s_cellShift, (bottom - 1) >> s_cellShift};
        if (cells.m_maxX < cells.m_minX)
        {
            cells.m_maxX = cells.m_minX;
        }
        if (cells.m_maxY < cells.m_minY)
        {
            cells.m_maxY = cells.m_minY;
        }
        return cells;
    }

    bool isTooWide(const Cells &cells)
    {
        return (cells.m_maxX - cells.m_minX + 1) * (cells.m_maxY - cells.m_minY + 1) > s_maxCells;
    }
}

extern "C"
{
    int fried_colliders_create(void)
    {
        return s_stores.store(new Store());
    }

    void fried_colliders_destroy(int store)
    {
        delete s_stores.release(store);
    }

    void fried_colliders_reset(int storeId, int count)
    {
        Store *store = s_stores.get(storeId);
        if (!store)
        {
            return;
        }
        const Entry empty = {0, 0, 0, 0, 0, 0, 0, 0, 0, false, false};
        store->m_entries.assign((size_t)count, empty);
        for (std::vector<int> &bucket : store->m_buckets)
        {
            bucket.clear();
        }
        store->m_large.clear();
        store->m_stamp = 0;
    }

    void fried_colliders_place(int storeId, int index, int left, int top, int right, int bottom)
    {
        Store *store = s_stores.get(storeId);
        if (!store || index < 0 || index >= (int)store->m_entries.size())
        {
            return;
        }
        Entry &entry = store->m_entries[index];
        entry.m_left = left;
        entry.m_top = top;
        entry.m_right = right;
        entry.m_bottom = bottom;
        Cells cells = cellsOf(left, top, right, bottom);
        if (entry.m_isInGrid && entry.m_cellMinX == cells.m_minX && entry.m_cellMinY == cells.m_minY && entry.m_cellMaxX == cells.m_maxX && entry.m_cellMaxY == cells.m_maxY)
        {
            return;
        }
        if (entry.m_isInGrid)
        {
            remove(*store, index);
        }
        entry.m_cellMinX = cells.m_minX;
        entry.m_cellMinY = cells.m_minY;
        entry.m_cellMaxX = cells.m_maxX;
        entry.m_cellMaxY = cells.m_maxY;
        entry.m_isInGrid = true;
        if (isTooWide(cells))
        {
            entry.m_isLarge = true;
            store->m_large.push_back(index);
            return;
        }
        entry.m_isLarge = false;
        for (int cellY = cells.m_minY; cellY <= cells.m_maxY; ++cellY)
        {
            for (int cellX = cells.m_minX; cellX <= cells.m_maxX; ++cellX)
            {
                store->m_buckets[bucketOf(cellX, cellY)].push_back(index);
            }
        }
    }

    int fried_colliders_candidates(int storeId, int left, int top, int right, int bottom, int *out)
    {
        Store *store = s_stores.get(storeId);
        if (!store)
        {
            return 0;
        }
        int total = (int)store->m_entries.size();
        Cells cells = cellsOf(left, top, right, bottom);
        if (isTooWide(cells))
        {
            for (int index = 0; index < total; ++index)
            {
                out[index] = index;
            }
            return total;
        }
        int stamp = ++store->m_stamp;
        int count = 0;
        for (int index : store->m_large)
        {
            store->m_entries[index].m_stamp = stamp;
            out[count++] = index;
        }
        for (int cellY = cells.m_minY; cellY <= cells.m_maxY; ++cellY)
        {
            for (int cellX = cells.m_minX; cellX <= cells.m_maxX; ++cellX)
            {
                for (int index : store->m_buckets[bucketOf(cellX, cellY)])
                {
                    Entry &entry = store->m_entries[index];
                    if (entry.m_stamp != stamp)
                    {
                        entry.m_stamp = stamp;
                        out[count++] = index;
                    }
                }
            }
        }
        return count;
    }

    int fried_colliders_overlapping(int storeId, int left, int top, int right, int bottom, int *out)
    {
        Store *store = s_stores.get(storeId);
        if (!store)
        {
            return 0;
        }
        int candidates = fried_colliders_candidates(storeId, left, top, right, bottom, out);
        int count = 0;
        for (int position = 0; position < candidates; ++position)
        {
            int index = out[position];
            const Entry &entry = store->m_entries[index];
            if (left < entry.m_right && right > entry.m_left && top < entry.m_bottom && bottom > entry.m_top)
            {
                out[count++] = index;
            }
        }
        std::sort(out, out + count);
        return count;
    }
}
