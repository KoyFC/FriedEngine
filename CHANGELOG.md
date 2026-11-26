# Changelog

All notable changes to Fried Engine are written here, newest version first.

- Changes go under the topmost `## vX.Y.Z` heading while they are in development. That heading is the version in progress and has no date.
- When a version is published, replace `vX.Y.Z` with its number and add the date (`## v0.3.0 - 2026-12-01`), and start a new `## vX.Y.Z` section above it.
- Each section uses `Added`, `Changed`, `Fixed` and `Removed`, and leaves out the ones it has no entries for.
- The Release workflow copies a version's section into its GitHub release, see [Releasing](https://koyfc.github.io/FriedEngine/development/releasing/).

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
