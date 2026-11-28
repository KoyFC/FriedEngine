# Changelog

All notable changes to Fried Engine are written here, newest version first.

- Changes go under the topmost `## vX.Y.Z` heading while they are in development. That heading is the version in progress and has no date.
- When a version is published, replace `vX.Y.Z` with its number and add the date (`## v0.3.0 - 2026-12-01`), and start a new `## vX.Y.Z` section above it.
- Each section uses `Added`, `Changed`, `Fixed` and `Removed`, and leaves out the ones it has no entries for.
- The Release workflow copies a version's section into its GitHub release, see [Releasing](https://koyfc.github.io/FriedEngine/development/releasing/).

## vX.Y.Z

### Changed
- The Haxe code of a DS game is built with `-Os` (`-DFRIED_DS_SIZE=OFF` to build it as before), 314 KB less code in the sandbox, which is heap for the game: in melonDS the 3D scene has about 567 KB free instead of 260. Its string literals are aligned by `cmake/nds/aligned_strings.h`, since `-Os` stopped GCC doing it.
- A build registers only the node and resource types the scenes of the project name, plus its autoloads and the classes a game registers itself, so the code of `UIDocument`, `Tilemap`, the meshes and the rest is left out of a game that does not use it: a project with a sprite and a camera has a quarter less code on the DS. The editor, `-D fried_text_scenes` and `-D fried_all_nodes` register every type, as before.
- A `Mesh` keeps at most four variants, one for each material that overrides its own, instead of one more for every scene that loads a cached model with an override.
- On the DS a mesh gives back its flat arrays of vertices, texture coordinates and indices once the console has its copy.
- A 3DS build compiles SDL2 and its companions itself on the first configure, as PC does, so it no longer needs `packaging/3ds/` installed; `FRIED_SYSTEM_SDL2=ON` keeps using those packages.

### Fixed
- A `UIDocument` left its font lookups, and the style sheets they held, in a static list for good, about 4 KB for every time a scene with one loaded.
- On the DS the collector no longer finds pointers to the scene that was just unloaded in the stack below the scene change, which kept all of it alive now and then: the sandbox's scene cycle stopped after 37 to 52 changes in melonDS and now goes through 60.
- The romfs and VPK packaging listed assets by the name of the source, so a scene, which is a `.fscene` once imported, was missing from the DS, 3DS, Switch and Vita packages.

### Added
- YAML for `project.fried`, scenes (`.scene.yaml`) and import settings, in a small subset that is a superset of JSON, so a project in JSON still builds and loads. `fried.io.Yaml` reads it in Haxe, `fried_import` in C++, and errors name the line and column.
- Scenes compiled to a binary `.fscene` by `fried_import`, read without parsing any text. The build refuses a scene the loader would refuse, and the YAML reader is left out of a game; the editor's player and `-D fried_text_scenes` read the text.
- LZ10 compression of compiled scenes, models, HTML and CSS, and of the fonts the DS and the fx-CG50 draw, which `compress: lz` in an import sidecar asks for.
- `optimize`, `lto` and `pc.compressExecutable` in `project.fried`: a build for size, link time optimization and UPX, and a `.gz` and `.br` of the web build. A computer build now drops unused functions at link time and strips its executable.
- Primitive meshes for a `MeshInstance3D`, `BoxMesh`, `SphereMesh`, `CylinderMesh`, `CapsuleMesh`, `PlaneMesh`, `PrismMesh` and `TorusMesh`, which a scene file writes inside the node's `mesh` field with their own numbers, and `StandardMaterial3D`, a color and an image for a surface.
- Textures on meshes where the renderer can paint them: the SDL renderer's GL on PC and the Switch, and triangles bent over the image everywhere SDL draws them, such as the web.
- Models read from `.obj` with `.mtl`, `.gltf` and `.glb` files: the asset import tool converts them to a compact format, a PC game that is being edited converts them as it reads them, and `MeshInstance3D.mesh` can be one. Every node of a file is one mesh with a surface for each material.
- `MeshInstance3D.materialOverride`, which paints every surface of the mesh with one material.
- `fried.resources.Resource`, the base of the data a scene file keeps inside a field, with its own `@:serializable` and the `mesh` and `material` kinds of field.
- The editor player sends the resources a field can hold, and the protocol is 6.
- `Tilemap`, a node that draws a grid of tiles from one picture out of a native cell store, drawing only the tiles the screen shows, with `isSolid` to cover its cells with merged colliders.
- `UIDocument`, a node that shows a screen written in HTML and CSS: a small parser for each, a flex layout, `:hover`, `:active`, `:focus` and `:disabled`, a `StyleSheet` shared by every document that uses it, focus moved with a keyboard or a gamepad, and `@:ui("file.html")` classes compiled against their HTML so an element's id, its `onclick` and its `{{text}}` are typed fields and methods.
- Rounded corners, gradients and shadows in a `UIDocument`, drawn plain on the DS and the fx-CG50.
- `fried.Profile`, section timers that exist only in a build made with `-D fried_profile`, and the game's frame stats carry them to the editor.

### Changed
- A DS build compiles the Haxe code of the game as Thumb, which leaves a fifth of the program to the heap, and `fried_application_free_memory()` and `Application.freeMemoryKb()` count what the heap has left, which the DS also prints when it runs out. A scene change collects and compacts the heap first where it is counted, native code that cannot get memory on the DS collects and tries again before giving up, and a mesh frees its native half when the collector takes it, so the DS no longer runs out of memory after a few changes of scene.
- `MeshInstance` is `MeshInstance3D`, and scene files that name the old type still load. Its `shape` and `color` are a `mesh` and a material: an older file is read as the primitive that comes nearest, and a `Pyramid` becomes a four sided cone that is turned an eighth of a turn about its axis.
- `fillTriangles()` has a sibling, `fillTexturedTriangles()`, and `fried_mesh_create()` takes the texture coordinates and the surfaces of a mesh.

### Removed
- `MeshShape` and `Primitives`, in favor of the primitive meshes.

## v0.1.0 - 2026-11-26

The first release. It is the engine as it stands now, written in Haxe on top of a native C++ core, with SDL2 on PC and native backends on the consoles.

### Platforms
- PC on Linux and Windows (MinGW cross builds and MSVC), the Web, Android (an engine library packaged as an APK), Nintendo Switch, 3DS and DS, PS Vita and Casio fx-CG50, each with its own renderer, input and filesystem.
- The 3DS has two screens and touch; the DS has its bottom screen and touchscreen, display lists and streamed music; the fx-CG50 has a cached frame, fonts and textures through gint.
- Per-platform display, icons, package text (3DS, DS), Vita Live Area, `pic0` boot splash and float precision, all read from `project.fried`, with the platforms a project builds for declared there too.
- Assets are converted for each platform through import sidecars when building.
- The engine is a static library used as a submodule.

### Core
- Application, windows (several, with a limit per platform, position and move event), events, frame pacing, unscaled time, `Time.timeScale` and a suspended game that can step a frame.
- Input: keyboard, mouse, gamepad, touch, a native event queue, accept and cancel buttons per platform and Unity-like input actions declared in `project.fried` and read by name.
- Logging with the call position and to a file, native error capturing, JSON save data and a writable user data path.
- Filesystem with engine and game assets, runtime asset resolution, texture, font and sound caching and a project class built from `project.fried`.
- A debug overlay and `Bootstrap` as the game's entry.

### Scenes and nodes
- A tree of nodes loaded from scene files, with serialization, object references and ids, scenes that instance other scenes, `PackedScene`, a `SceneManager` and autoload scenes or node classes that outlive scene changes.
- 2D nodes: `Sprite`, `Camera`, `Collider`, `KinematicBody`, `Label`, `Button`, `TextureRect`, `CanvasLayer` and controls laid out against their parent with a `RectTransform` (anchors, pivot, offsets and stretch).
- Touch controls: `TouchButton` and `VirtualJoystick`, which hold input actions, with a choice of where a game shows them.
- Layers with deferred management and events.
- 3D: `Node3D`, `Camera3D` with a far plane and `MeshInstance` with built-in shapes and `DirectionalLight`, drawn with OpenGL on PC, OpenGL ES on the Switch and Vita, citro3d on the 3DS, the DS 3D engine and GXM on the Vita, with a software fallback.
- Physics: raycasts, colliders and kinematic bodies moved in a fixed step, with overlaps tested in fixed point and found through a spatial grid.

### Rendering and text
- A renderer and textures with a draw queue by priority, transforms, color, filters and downscaling, and one draw call for a frame's sprites and rectangles.
- Display modes: native, pixel, fixed height and expand, with a logical display scaled by each renderer, optional linear filtering and vsync read from the project.
- Fonts rasterized at the on-screen scale, glyph and text atlases, line packing, breaking text at a maximum width and the Nunito Sans font.
- A software renderer that only redraws what changes.

### Editor support
- Play mode with the game running inside the editor, keys and mouse sent to it, a preview through the game's cameras, running node values and frame pacing.
- Reporting each node's bounds, origin and camera view to the editor, a layout pass before every draw and the project's design size.
- Renderer pixel readback and an editor frame hook.

### Tooling
- Builds with hxcpp (including its `EReg` regexp) and full Haxe dead code elimination, with dependencies cached in a local path.
- A Sandbox that exercises the engine on every platform.
- Documentation site on GitHub Pages with an API reference, platform feature table and project file reference, published with GitHub Actions.
- MIT license.
