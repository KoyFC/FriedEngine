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

## Later

A second UI backend (Dear ImGui), a binary cooked scene format, prefabs, hierarchy, a `screen` field for dual-screen platforms, 3D components, user components in the viewport, per-platform asset variants.
