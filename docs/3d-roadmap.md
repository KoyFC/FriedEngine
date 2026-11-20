# 3D roadmap

Software 3D in Haxe, drawn with `fillTriangles()`, or meshes drawn by the renderer's own GPU where it has a backend for them. See the 3D section of [`ARCHITECTURE.md`](../ARCHITECTURE.md) for how it works.

## Done

- [x] `fillTriangles()` in the SDL, citro2d and gint renderers
- [x] `fried.graphics3d`: mesh, fixed camera, directional light, back-face culling, per-mesh sort
- [x] `SceneManager`, with the sandbox split into a 2D and a 3D scene
- [x] 3D stress test scene
- [x] Meshes drawn by the DS's 3D engine on its top screen
- [x] Camera3D, DirectionalLight and MeshInstance nodes; a scene sorts the triangles of all its meshes together and submits one batch
- [x] Clipping at the near plane, skipping meshes outside the view by bounding sphere, and a free camera in the sandbox's 3D scene
- [x] Built-in shapes for MeshInstance
- [x] Camera rotation on the DS's 3D engine
- [x] OpenGL depth buffer backend on PC (SDL's `opengl` driver), with the far plane passed to every renderer that draws meshes
- [x] Node3D: position, rotation about each axis in Unity's order and scale on each, its world values cached like a Node2D's

## Constraints

- `Camera3D.far` is not enforced on the DS, whose 3D engine orders meshes without a far plane
- Meshes are drawn as triangles, in painter's order, wherever the renderer draws none: every platform but the DS and PC, and PC when SDL has no OpenGL context with a depth buffer

- Works on every platform except the fx-CG50, which keeps the `fillTriangles()` it has now and gets no further 3D support
- Games only use nodes, so a GPU backend can replace the pipeline later
- No per-frame allocations
- Intersecting triangles still sort wrong without a depth buffer, which is the case on the platforms above

## Later

- `.obj` loading
- Textures
- Point lights, vertex colors
- Parenting a mesh under another mesh
- GPU backends for the Switch, the Vita and the 3DS
