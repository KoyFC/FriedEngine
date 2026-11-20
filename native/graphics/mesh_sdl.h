#pragma once

// What renderer_sdl.cpp tells the mesh backend about the SDL renderer it
// draws with. Only one renderer at a time draws meshes: attaching another
// leaves it without them, and MeshPass then draws its meshes as triangles.

// True once the renderer can depth test and its program compiled.
bool fried_mesh_sdl_attach(int rendererId, void *sdlRenderer);

// Frees what the backend made in the renderer, which has to still be alive.
void fried_mesh_sdl_detach(int rendererId);

// The depth buffer starts again with the next frame.
void fried_mesh_sdl_end_frame(int rendererId);

// Meshes are drawn one after another with the GPU state they need left set, and
// SDL's own state put back only when something else is about to use the
// context or scene. Everything in the renderer and texture files that touches SDL
// calls this first.
void fried_mesh_sdl_leave();
