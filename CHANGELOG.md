# Changelog

All notable changes to Fried Engine are written here, newest version first.

- Changes go under the topmost `## vX.Y.Z` heading while they are in development. That heading is the version in progress and has no date.
- When a version is published, replace `vX.Y.Z` with its number and add the date (`## v0.3.0 - 2026-12-01`), and start a new `## vX.Y.Z` section above it.
- Each section uses `Added`, `Changed`, `Fixed` and `Removed`, and leaves out the ones it has no entries for.
- To get the notes of a release for GitHub: `awk '/^## v0.3.0/{f=1;next} /^## /{f=0} f' CHANGELOG.md`, then `gh release create v0.3.0 --notes-file -`.

The engine has no tagged release yet. The first one is `vX.Y.Z` below; the work before 2026-11-19 is in the git history.

## vX.Y.Z

### Added
- Android as a platform: the engine builds as an Android library, games package as an APK, assets are read through SDL and every touch device is treated as the screen.
- On-screen controls: `TouchButton` and `VirtualJoystick` nodes that hold input actions, a choice of where a game shows them, and a demo in the Sandbox.
- 3D: `Node3D`, `Camera3D` (with a far plane) and `MeshInstance` with built-in shapes, drawn with OpenGL on PC, OpenGL ES on the Switch and Vita (Piglet), citro3d on the 3DS, display lists on the DS and GXM on the Vita, with a software fallback.
- `CanvasLayer`, scenes that instance other scenes, `PackedScene`, and autoload scenes or node classes listed in `project.fried` that outlive scene changes.
- Input actions declared in `project.fried` and read by name.
- `Time.timeScale` with real unscaled time, and a game that can be suspended and stepped one frame.
- Editor support: play mode, keys and mouse, preview through the game's cameras, running node values, frame pacing and play window size.
- Per-platform float precision, platforms a project builds for, and asset conversion through import sidecars.
- Documentation site on GitHub Pages with an API reference, a Platforms page with a feature table, and a project file reference.
- MIT license.

### Changed
- Haxe is built with full dead code elimination.
- 2D transforms and collider boxes live in native stores, and positions, sizes and angles are stored as single precision.
- A scene file must have exactly one root node.
- The Game class is gone: the editor watches Bootstrap through an observer.
- DS: batch drawing stays in ITCM, mesh arrays are reserved only where needed and TrueType fonts drop unused tables.

### Fixed
- Build hxcpp's Regexp for games that use `EReg`.
- Fixed the Vita icon color format.
- The VPK target is depended on under the name the VitaSDK gives it.
- The DS stops with a message when it runs out of memory.
