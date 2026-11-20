#pragma once

#include "graphics/display.h"

// What renderer_citro.cpp tells the citro3d mesh backend about the screen a
// mesh is drawn on.

// Draws a mesh onto a screen of the given size in output pixels, leaving the GPU set up for meshes until fried_mesh_citro_leave().
void fried_mesh_citro_draw(int meshId, const double *placement, bool hasCamera, double zoom, double cameraX, double cameraY,
                           const FriedDisplayLayout &layout, int outputWidth, int outputHeight);

// Puts citro2d's state back, when meshes have been drawn since it last was.
void fried_mesh_citro_leave();

// Frees the shader program, before citro3d is shut down.
void fried_mesh_citro_stop();
