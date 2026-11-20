# Editor roadmap

A scene editor for Fried Engine lives in its own repository, [FriedEditor](https://github.com/KoyFC/FriedEditor), with the same roadmap in its `ROADMAP.md`. The engine owns the runtime half: a scene file format and loader, node serialization, and a headless "editor player" the editor drives to draw its viewport. The editor owns everything the user sees. Items below say which repository owns them.

## Decisions

- A scene is a tree of typed nodes, 2D and 3D, and a game adds its own with `NodeRegistry.register()` (see [Scene files](../architecture/scene-files.md)).
- A scene is a JSON file under `assets/scenes/`, written by the editor and only read by the engine. Objects have stable ids, and there are no per-platform values: a node that differs on a platform decides so in its own code.
- The reference resolution is the project's `display` block, not a field of the scene.
- Nodes are serialized through the `NodeBuilder` build macro, with no runtime reflection and an explicit registry of the built-ins (`Builtins` and `NodeRegistry`).
- The viewport is a separate engine process, driven by a small protocol (see [the editor player page](../architecture/editor-player.md)): `schema`, `load` for structural changes, `setField` for edits, `render` (`-D fried-editor`) that renders offscreen on request and talks to the editor over loopback TCP. User nodes are compiled Haxe, so each project has a player of its own, built from its `editor.hxml` and rebuilt when its sources change.
- The editor is split into a UI-independent core and swappable UI backends: Dear ImGui is the one in use, and Qt stays as a second backend.

## Open work

### 1. Spikes (throwaway code, results recorded here)

- [ ] A: loader round trip, sandbox scene from JSON on PC and on a console, plus `haxe.Json` cost on the DS and fx-CG50

### 14. Nodes (FriedEngine, then FriedEditor)

- [ ] The editor on nodes: a tree in the hierarchy panel, one inspector section per class, and structural changes sent as `addNode`, `removeNode` and `moveNode`
- [ ] The Project Manager's template and WhiteCellSimulator on nodes

## Notes

Known limits: an object that other objects refer to cannot be deleted without fixing those references first, or the scene fails to load, and a game component is selected by its `width` and `height` or a fixed 16 pixel marker.

The editor lays a scene out against the project's display size, not the panel's, so a position taken from the view, such as the right edge, is shown where the game puts it. Layout is tested on WhiteCellSimulator's start, gameover and hud scenes.

## Later

A binary cooked scene format, prefabs, a `screen` field for dual-screen platforms, per-platform asset variants.
