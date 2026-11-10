# Editor roadmap

A scene editor for Fried Engine lives in its own repository, [FriedEditor](https://github.com/KoyFC/FriedEditor), with the same roadmap in its `ROADMAP.md`. The engine owns the runtime half: a scene file format and loader, component serialization, and a headless "editor player" the editor drives to draw its viewport. The editor owns everything the user sees. Items below say which repository owns them.

## Decisions

- v1 is 2D only, with no hierarchy and built-in components only.
- A scene is a JSON file under `assets/scenes/`, written by the editor and only read by the engine. Objects have stable ids, and a `platforms` block holds per-platform overrides keyed like `project.fried`.
- The reference resolution is the project's `display` block, not a field of the scene.
- Components are serialized through a build macro on `Component`, with no runtime reflection and an explicit registry of the built-ins.
- The viewport is a separate engine process, driven by a small protocol (see the editor player section of `ARCHITECTURE.md`): `schema`, `load` for structural changes, `setField` for edits, `render` (`-D fried-editor`) that renders offscreen on request and talks to the editor over loopback TCP. User components cannot be shown in it until a per-project player exists, because they are compiled Haxe.
- The editor is split into a UI-independent core and swappable UI backends: Dear ImGui is the one in use, and Qt stays as a second backend.

## Phases

### 0. Roadmap in both repositories

- [x] This file, and `ROADMAP.md` in FriedEditor

### 1. Spikes (throwaway code, results recorded here)

- [ ] A: loader round trip, sandbox scene from JSON on PC and on a console, plus `haxe.Json` cost on the DS and fx-CG50
- [x] B: offscreen frames from the engine into a Qt widget on a Wayland session

### 2. Engine core (FriedEngine)

- [x] `GameObject.id`, `Scene.findById`, `Scene.findByName`
- [x] `Filesystem.resolveAsset(root, path)` with path validation
- [x] `ComponentBuilder` macro, `ComponentRegistry` and the built-in list
- [x] `SceneLoader` and a sandbox scene loaded from JSON
- [x] `Application.platformName` and per-platform overrides

### 3. Editor player (FriedEngine)

- [x] `Renderer.readPixels()` (no software fallback needed: `SDL_RENDER_DRIVER=software` is enough)
- [x] `Application.onBeforePresent` and `EditorSceneLayer`
- [x] Protocol, object bounds, schema reply, live asset roots, `editor/player/` target

### 4. Editor skeleton (FriedEditor)

- [x] CMake with `core/`, `core_tests` and `ui/qt/`
- [x] Project and platform model in core (build targets come with play mode)
- [x] Subprocess, TCP listener and message framing (POSIX only so far)
- [x] Player session: build, launch, handshake, schema

### 5. Scene editing (FriedEditor)

- [x] Scene document with load and save
- [x] Undo and redo commands
- [x] Viewport with pan, zoom and selection
- [x] Hierarchy panel
- [x] Inspector generated from the schema
- [x] Asset browser, drag a texture to create a sprite
- [x] Move, scale and rotate gizmos

### 6. Per-platform (FriedEditor)

- [x] Platform selector and override editing
- [x] Display frame from `project.fried`
- [x] Asset validation with fixes (texture sizes, DS audio format, fx-CG50 size)

### 7. Play mode (FriedEditor)

- [x] Build and run the game for PC from the editor

### 8. The sandbox as scene files (FriedEngine and FriedEditor)

- [x] Object references between components, and a registry for a game's own components
- [x] A player per project, built from its `editor.hxml`, rebuilt when its sources change
- [x] The sandbox's 2D scene and its interface layer as `sandbox.scene.json` and `sandbox_ui.scene.json`, with the same frame as the scene built in code
- [x] Open Scene in the editor

Known limits: an object that other objects refer to cannot be deleted without fixing those references first, or the scene fails to load, and a game component is selected by its `width` and `height` or a fixed 16 pixel marker.

### 9. Projects driven by the editor (FriedEngine and FriedEditor)

- [x] Components start after a scene file is fully loaded, and never in the editor player
- [x] A component can read the size of the view it is drawn to without holding the renderer
- [x] A scene can be loaded on top of another, and a scene with no camera is screen space
- [x] The engine opens the window and loads the scene `project.fried` names, with an optional `Game` class for what a game needs once
- [x] The components of a project are found without a list to maintain
- [x] Components no longer receive the renderer or the layers (`DrawQueue.currentRenderTarget` is still public, for the engine's own drawing)
- [x] The sandbox's sources are in folders by purpose, and it stays the engine's test bed, with WhiteCellSimulator as the project built in the editor's way

### 10. WhiteCellSimulator as scene files (its own repository)

- [x] Menu, game and game over as scenes, with the flow in a controller component
- [x] Enemies and projectiles as components with a texture field, still spawned from code
- [x] The second window of the 3DS stays in the `Game` hook
- [x] Small screens through a `cg50` override block instead of `Screen.scale`
- [x] Built for the PC and the fx-CG50 (the .g3a is 1.9 MB of 2 MB). Not run on a calculator, and the start screen was compared with the old one on the PC only

Known limit: a position that depends on the screen's size, such as the right edge, is set by a component, and the editor shows it unplaced because its player never updates.

### 11. Viewport and speed (FriedEngine and FriedEditor)

- [x] The player renders at the size of the panel, so a frame is not scaled
- [x] The display frame is the display's size divided by the zoom of the game camera on that platform
- [x] A pan step takes 4 ms instead of 43 (Nagle and a player that never slept), and the player is nearly idle when nothing is asked of it

### 12. Feedback while building and opening where it was left (FriedEditor)

- [x] A window with the step, a bar and the end of the log while the player or the game builds, and the error when it fails
- [x] The scene that was open is opened again the next time

## Later

A second UI backend (Dear ImGui), a binary cooked scene format, prefabs, hierarchy, a `screen` field for dual-screen platforms, 3D components, per-platform asset variants.
