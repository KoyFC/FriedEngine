# 3D roadmap

Software 3D in Haxe, drawn with `fillTriangles()`. See the 3D section of [`ARCHITECTURE.md`](../ARCHITECTURE.md) for how it works.

## Done

- [x] `fillTriangles()` in the SDL, citro2d and gint renderers
- [x] `fried.graphics3d`: mesh, fixed camera, directional light, back-face culling, per-mesh sort
- [x] `SceneManager`, with the sandbox split into a 2D and a 3D scene
- [x] 3D stress test scene

## Next

### 1. Unified transform

- `Transform` gets `z`, `rotationX`, `rotationY`, `rotationZ`, `scaleZ`
- `rotation` becomes `rotationZ` in 2D code (`Sprite`, `Text`, sandbox, template)
- 2D keeps y down; 3D is left handed with y up and z forward

### 2. Free camera

- `Camera3D` is a component that reads its object's `Transform`
- `fieldOfView`, `near`, `far` and `lookAt(x, y, z)`
- Rotation order z, x, y, like Unity
- `Scene.camera3D`, with the same rules as `Scene.camera`
- Remove `Transform3D` and `Vec3`

### 3. Mesh renderer and global sort

- `MeshRenderer` component; meshes can be shared
- Directional light as a component, direction from its rotation
- The scene sorts the triangles of all its meshes together and submits one batch
- Port the stress test to components

### 4. Clipping

- Clip triangles against the near plane instead of dropping them
- Skip meshes outside the frustum by bounding sphere
- Camera controls in the stress test

## Constraints

- Works on every platform except the fx-CG50, which keeps the `fillTriangles()` it has now and gets no further 3D support
- Games only use components, so a GPU backend can replace the pipeline later
- No per-frame allocations
- Intersecting triangles still sort wrong without a depth buffer

## Later

- `.obj` loading
- Textures
- Point lights, vertex colours
- Hierarchies
- GPU backends (OpenGL, citro3d, GXM)
