#pragma once

extern "C"
{
    // The boxes of a scene's colliders as integers in 20.12 (math/fixed_point.h), kept together in one array indexed by the collider's place in tree order, with the grid that finds the ones near a box. Haxe keeps the colliders themselves and maps an index back to one.
    int fried_colliders_create(void);
    void fried_colliders_destroy(int store);
    // Forgets every box and makes room for count colliders, as when a node enters or leaves the scene.
    void fried_colliders_reset(int store, int count);
    // Sets one collider's box, and files it under the grid cells that box covers, unless they are the cells it was already in.
    void fried_colliders_place(int store, int index, int left, int top, int right, int bottom);
    // Writes to out the index of every collider that may touch the box, each once, and returns how many: those in the cells it covers and those too big for cells, or all of them when the box covers many cells. Nothing is promised about their order, or that they do touch it. out holds as many ints as the store has colliders.
    int fried_colliders_candidates(int store, int left, int top, int right, int bottom, int *out);
    // Writes to out the index of every collider whose box overlaps the box, as boxes that only touch do not, in ascending order, and returns how many.
    int fried_colliders_overlapping(int store, int left, int top, int right, int bottom, int *out);
}
