#pragma once

// What renderer_sdl.cpp tells the OpenGL mesh backend about the renderer it
// draws with. Only one renderer at a time draws meshes: attaching another
// leaves it without them, and MeshPass then draws its meshes as triangles.

// True once the renderer's context can depth test and its program compiled.
bool fried_mesh_gl_attach(int rendererId, void *sdlRenderer);

// Frees what the backend made in the renderer's context, which has to still be alive.
void fried_mesh_gl_detach(int rendererId);

// The depth buffer starts again with the next frame.
void fried_mesh_gl_end_frame(int rendererId);

// Meshes are drawn one after another with the GL state they need left set, and
// SDL's own state put back only when something else is about to use the
// context. Everything in the renderer and texture files that touches SDL
// calls this first.
void fried_mesh_gl_leave();
