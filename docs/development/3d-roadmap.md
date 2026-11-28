# 3D roadmap

Software 3D in Haxe, drawn with `fillTriangles()`, or meshes drawn by the renderer's own GPU where it has a backend for them. See the [3D page of the architecture](../architecture/3d.md) for how it works. Its [limitations](../architecture/3d.md#limitations) are listed there too.

## Later

- Textures on the Vita, 3DS and DS
- The average color of an image, for the renderers that cannot paint it
- Smooth shading, with normals in a mesh and in the files that have them
- Point lights, vertex colors
- A material for each surface of a model that an object can replace, and not only all of them
- Parenting a mesh under another mesh, and keeping the nodes of a glTF scene as objects
