# Meshes, materials and models

A `MeshInstance3D` draws a `Mesh`, and a mesh is made of surfaces that each have a `Material`. This page is about what a mesh can be, how a scene file writes it and how a model made in another tool becomes one. How a mesh is turned into pixels is on the [3D page](3d.md).

## The mesh of a node

`MeshInstance3D.mesh` is one of the primitive meshes below, or a model file. A primitive is a resource: a scene file writes it inside the field, with the `type` that names it and the numbers that describe it, and a number it leaves out has its default.

```json
{
  "type": "MeshInstance3D",
  "id": "ball",
  "mesh": {
    "type": "SphereMesh",
    "radius": 0.5,
    "material": {
      "type": "StandardMaterial3D",
      "albedoColor": {"r": 240, "g": 200, "b": 80, "a": 255},
      "albedoTexture": {"root": "game", "path": "textures/rock.png"}
    }
  }
}
```

A model is written as the file it is read from, which is how a texture is:

```json
"mesh": {"root": "game", "path": "models/ship.glb"}
```

`materialOverride` paints every surface of the mesh with one material, in place of their own. It is how a model is used in two colors without a second file.

| Mesh | Fields (defaults) |
|---|---|
| `BoxMesh` | `sizeX`, `sizeY`, `sizeZ` (1), `subdivideWidth`, `subdivideHeight`, `subdivideDepth` (0) |
| `SphereMesh` | `radius` (0.5), `height` (1), `radialSegments` (16), `rings` (8), `isHemisphere` |
| `CylinderMesh` | `topRadius`, `bottomRadius` (0.5), `height` (2), `radialSegments` (16), `rings` (0), `capTop`, `capBottom` (on) |
| `CapsuleMesh` | `radius` (0.5), `height` (2, the whole length), `radialSegments` (16), `rings` (4) |
| `PlaneMesh` | `sizeX`, `sizeZ` (2), `subdivideWidth`, `subdivideDepth` (0), `orientation` (`FaceX`, `FaceY`, `FaceZ`) |
| `PrismMesh` | `leftToRight` (0.5), `sizeX`, `sizeY`, `sizeZ` (1) |
| `TorusMesh` | `innerRadius` (0.5), `outerRadius` (1), `rings` (16), `ringSegments` (8) |

They are the shapes of Godot's `PrimitiveMesh` classes, with fewer segments by default because the DS draws 2048 polygons a frame, and without normals, since every face is shaded flat. A primitive is made when it is first drawn and again after a field changes. `PlaneMesh` is drawn from one side, the one it faces, and its `sizeX` goes across as seen from that side and its `sizeZ` down. A mesh that is not shared with other objects is not shared in the renderer either, so a scene with many equal primitives should use one `Mesh` object from code.

In the editor the `mesh` field is a list of these types and `File...`, and the fields of the one chosen appear under it.

## Materials

A `StandardMaterial3D` has an `albedoColor`, which multiplies the color of every triangle, and an `albedoTexture`, an image that it multiplies. A material has a `version` that goes up when it changes, and a mesh makes its copy in the renderer again when the version of a material it uses is not the one the copy was made with, so a material can be changed while the game runs, at the price of a copy: do not animate one.

A texture painted on a triangle comes from the surface's texture coordinates, with (0, 0) at the top left of the image and v growing downward, as in glTF and in 2D drawing. A coordinate outside the image repeats the image on the platforms that can, and takes the color of its edge on the others. Pixels of the image that are not at least half opaque are not drawn.

## Space

The engine is left handed, with y up and z going away from the camera. A triangle is in front when its corners go round clockwise as seen from outside. OBJ and glTF files are right handed and have their front counterclockwise, so the importer mirrors x, which also turns every triangle round. A model looks as it does in the tool that made it, mirrored the way Unity mirrors it.

## Model files

`.obj` files are read with their `.mtl`: each material becomes a surface, `Kd` is its color, `d` or `Tr` its opacity and `map_Kd` its image, polygons are cut into triangles and a negative index counts from the end. `.gltf` and `.glb` files are read with their buffers: the nodes of the default scene have their transforms applied to their vertices, a mirrored transform turns its triangles round, `baseColorFactor` and `baseColorTexture` give each material its color and image, and triangle strips and fans are cut into triangles. Everything in a file becomes one mesh with a surface for each material. Normals, vertex colors, skins, animations, cameras and lights are not read.

The asset import tool converts them while it builds, as it does images and sounds. The file keeps its name and its place in the assets, and holds `FRMS`, a compact little endian format, so a model needs no parser on the platform:

| | |
|---|---|
| Header | `FRMS`, a `u16` version (1), a `u16` of flags (0), a `u32` count of surfaces |
| Each surface | `u32` vertices, `u32` triangles, `u32` flags (bit 0 has texture coordinates, bit 1 has `u32` indices), `u32` ARGB color, `u32` kind of image (0 none, 1 path, 2 PNG inside) |
| Image | for 1 and 2, a `u32` length and the bytes of a UTF-8 path relative to the model or of a PNG, padded to four |
| Data | `f32` x, y, z of each vertex, `f32` u, v of each vertex if it has them, the indices of each triangle as `u16` or `u32`, padded to four |

An image that is inside a glTF file, or is not a PNG, is written as a PNG beside the model (`ship.glb.body.png`) and named by its path, so the platform loads it as it does any other image and a sidecar of its own can still apply. On the fx-CG50 the image is left out and its average is multiplied into the surface's color. The tool warns when a model has more than 2048 triangles or 6144 vertices for the DS.

A PC game that is being edited has the project's own files, which the tool has not converted, so it converts them as it reads them. The editor's player and a game started from the editor are in that case. Elsewhere a file that is not `FRMS` is an error.

## What each platform draws

| | Meshes | Textures on meshes |
|---|---|---|
| PC, Switch | GL with a depth buffer | Yes, repeating where the image is not padded |
| Web, and PC without a depth buffer | triangles in painter's order | Yes, bent over each triangle with no account of depth, so a large triangle looks warped |
| Vita, 3DS, DS | the console's GPU | Not yet: a surface is painted with its color alone |
| fx-CG50 | triangles in painter's order | No: its color alone |
