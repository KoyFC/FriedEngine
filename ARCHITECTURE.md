# Fried Engine Architecture

This document describes the **currently implemented** architecture of this repository. See `README.md` for the roadmap of what's coming.

## Scope of this repository

This repository is Fried Engine itself. Fried Build, Fried CLI and Fried Project Manager are separate tools, not yet built, that will live in their own repositories and consume this one as a dependency (a game project will pull this repo in as a pinned Git submodule). None of them exist yet.

## Build pipeline (implemented)

```
Haxe  --(hxcpp)-->  generated C++  --(CMake)-->  compiler  -->  executable
```

A minimal sandbox Haxe program is compiled to C++ by hxcpp (`haxe build.hxml`, using `-D no-compilation` to stop before hxcpp's own build tool would run), and that generated C++ is then compiled and linked purely by CMake. `cmake/Hxcpp.cmake` locates the `hxcpp` haxelib and compiles its runtime sources alongside the generated code, with no dependency on hxcpp's own `Build.xml`/`haxelib run hxcpp` build tool.

CMake is meant to be the build system for every platform this engine will target, but only the PC/CMake path above is actually implemented and verified so far.

## SDL2 (implemented)

SDL2 is linked via CMake's own package config (`find_package(SDL2 CONFIG)`, `SDL2::SDL2`), together with its three companion libraries, SDL2_image, SDL2_mixer and SDL2_ttf, each found and linked the same way. They are initialized and torn down alongside SDL itself in `application.cpp` (`IMG_Init` for PNG, `TTF_Init`, `Mix_OpenAudio` at 44100Hz stereo), so that a failure to bring one up fails `fried.Application.init()` rather than surfacing later, at the first load. Nothing loads through them yet: `Texture`/`Sound`/`Music`/`Font` arrive with the Renderer. `native/` holds small, hand-written C glue files that wrap the specific SDL2 calls the engine needs (`application.cpp`: `SDL_Init`/`SDL_Quit`; `events.cpp`: polling for `SDL_QUIT`, also forwarding `SDL_MOUSEWHEEL` events to `mouse.cpp` since SDL2 only reports the wheel through events, not a poll-able state, and translating `SDL_WINDOWEVENT` into a small queue of window events that Haxe drains once SDL polling is over; `window.cpp`: creating/destroying an `SDL_Window`, tracked by integer handle so no SDL pointer types cross into Haxe, resolving SDL's own window id back to that handle for `events.cpp`, and repainting every live window's surface once per frame; `input.cpp`: querying `SDL_GetKeyboardState`; `filesystem.cpp`: `SDL_GetBasePath` and the asset root derived from it; `mouse.cpp`: querying `SDL_GetMouseState` and accumulating wheel deltas reported by `events.cpp`). Each is bound to Haxe through a small `extern class` in the matching `fried.*` class. Game code never sees SDL2 directly, only `fried.Application`/`fried.Window`/`fried.Events`/`fried.Input`.

## Runtime (implemented so far)

`src/fried/` holds the engine's own Haxe code, package `fried`:

- `fried.Log`: `info`/`warn`/`error`, printing to stdout/stderr.
- `fried.Time`: `start()`/`tick()`, exposing `deltaSeconds`, `elapsedSeconds`, `frameCount`.
- `fried.Window`: creates/destroys an SDL window (resizable), exposes `width`/`height`, and exposes the window's events as assignable callbacks: `onClose`, `onResize(width, height)` and `onFocusChanged(focused)`, all null until the game sets them. Resizes are reported from SDL's `SDL_WINDOWEVENT_SIZE_CHANGED` rather than `SDL_WINDOWEVENT_RESIZED`, since SDL only sends the latter for size changes the user or window manager caused. Reacting to a resize is optional: `width`/`height` always query SDL for the live size, so code that simply reads them every frame stays correct without touching the callbacks at all. On Wayland a window only takes its new size once the client commits a buffer at that size, so `fried.Application`'s loop presents every window once per frame (`native/window.cpp`'s `fried_window_present_all`, currently just a black fill); without it the user cannot resize the window at all, since nothing the engine draws ever reaches the compositor after the first frame. This is a placeholder for the Renderer, which will own presentation once it exists and cannot share a window with `SDL_GetWindowSurface`. A pure platform primitive: it does not own or know about a renderer (see the Window/Renderer decoupling this repo's design follows once a Renderer exists).
- `fried.Application`: owns the SDL lifecycle (`init`/`shutdown`) and the game loop itself: `run(update)` loops while `running` is true, pumping events (via `fried.Events`), ticking `fried.Time`, running `update`, presenting the windows and ending the frame for `fried.Input` (in that order) each iteration; `quit()` stops it. `targetFps` (60 by default, 0 to uncap) makes the loop sleep out whatever is left of the frame's budget, since nothing else in the engine blocks yet: uncapped, the loop spins a core at 100%. `Sys.sleep` only guarantees a minimum, so the real rate settles slightly under the target (measured: 59.2fps at 60, using around 5% of a core); hitting a target exactly needs vsync, which arrives with the Renderer.
- `fried.Events`: `pump():Bool`, true if the application should quit (currently: an `SDL_QUIT` event was seen). It also drains the window events `native/events.cpp` queued and dispatches each one to the callbacks of the `fried.Window` it belongs to, found through a registry `fried.Window` keeps by handle. Draining happens after the native pump has emptied SDL's queue, so a callback never runs while SDL state is still mid-update. Closing the last window needs no callback to work: SDL raises `SDL_QUIT` for it, which already ends the loop.
- `fried.Input`: keyboard and mouse, both following the same three-state naming (deliberately matching Unity's `GetKey`/`GetKeyDown`/`GetKeyUp`, not the more common `IsKeyDown`-means-held convention): `isKeyPressed`/`isButtonPressed` (true every frame the key/button is held, from the frame it went down through the frame before it comes back up), `isKeyDown`/`isButtonDown` (true only on the single frame it went down), `isKeyReleased`/`isButtonReleased` (true only on the single frame it came back up). Both compare SDL's live state (kept current as a side effect of `fried.Events.pump()`'s `SDL_PollEvent` calls) against a previous-frame snapshot `fried.Application.run()` refreshes once per frame. `fried.Key` is an enum abstract over SDL's stable `SDL_SCANCODE_*` values (letters, digits, F1-F12, arrows, common control/modifier keys) and `fried.MouseButton` likewise over SDL's button ids (`Left`/`Middle`/`Right`), keeping SDL2 constants out of game code. Mouse also exposes `mouseX`/`mouseY` (position) and `scrollX`/`scrollY` (wheel delta accumulated this frame, reset every frame); no gamepad yet.
- `fried.Filesystem`: where files are and how to read them, which is one question and so one class. Where: `basePath` (SDL's `SDL_GetBasePath()`, the directory the executable lives in) and the asset root, as `assetPath` plus `getAssetPath(relativePath)` which prefixes a path with it. `native/filesystem.cpp` is the single place that decides where a platform keeps its assets (currently `<basePath>assets/` everywhere); platforms with a fixed mount point, such as Vita's `app0:/` or Switch's `romfs:/`, change that one function and nothing above it. Engine and game code never branch on platform to open an asset, and never build a path out of `basePath` by hand, and in practice they do not touch `assetPath` either: they go through `fried.Assets` below, whose macros are the only callers of `getAssetPath()`. How to read: `exists(path)`/`readBytes(path)`, a thin wrapper over hxcpp's own `sys.FileSystem`/`sys.io.File` rather than native glue, since (unlike windowing/input) the `cpp` target already implements these natively and cross-platform-enough for the PC scope currently verified. The wrapper exists so the implementation can be swapped for native/SDL glue later without touching call sites, if a target platform's `sys` support proves inadequate (e.g. Vita/Switch). Reading is scoped to generic, non-media data (config, level data, `project.fried`); image/audio/font resources will not go through it. SDL's own libraries for those (SDL_image, SDL_mixer, SDL_ttf) load directly from a path and decode the format themselves, so `Texture`/`Sound`/`Music`/`Font` will each be their own wrapper over the matching SDL library, independent of `Filesystem`. The two halves have different implementations (native glue for the roots, `sys.*` for the reads) but that is behind the API, and it is exactly the swap the wrapper was written to allow.
- `fried.Assets`: resolves a path in one of the two asset roots, `engine(relativePath)` for `<assetPath>engine/` and `game(relativePath)` for `<assetPath>game/`. Both are macros, which is how the engine/game split and the existence of every asset are checked at compile time (below). It resolves paths and nothing else: reading is `fried.Filesystem` for generic data, and will be `Texture`/`Sound`/`Music`/`Font` for media, each of which takes a path.

All exercised together from `sandbox/src/Main.hx`, which adds `src/` to its Haxe classpath alongside its own `sandbox/src/`, standing in for a real game project. It keeps a small PNG and WAV in `sandbox/assets/` and the engine keeps a TTF in `assets/`, all three generated for this repository so nothing third-party is vendored (the font is a placeholder that draws every printable ASCII character as the same filled box, enough to prove `TTF_OpenFont` gets a real file), copied next to the executable by CMake on every build (the asset root is resolved from `SDL_GetBasePath()`, so the assets have to sit beside the binary, not beside the sources); the sandbox resolves one asset from each root through `fried.Assets` and checks at startup that it really is there, so a build that populated only one of them fails loudly even though the macro already proved both exist in the sources. Not built yet: the asset pipeline itself, the writable path for saves and user config, Renderer.

## Asset roots (implemented)

Assets sit under the asset root `fried.Filesystem` resolves, split in two: `engine/`, shipped by the engine, and `game/`, shipped by the game. Engine code may read only the engine root; game code may read both.

The split exists only in the runtime layout. Each side keeps its own assets in a plain `assets/` directory in its own repository, and CMake copies the engine's `assets/` to `assets/engine/` and the game's `assets/` to `assets/game/` next to the executable. The copy is its own `ALL` target that depends on the executable, not a `POST_BUILD` command on it, since `POST_BUILD` only fires when the target relinks and an added or edited asset would then never reach the build tree. A game therefore never names the word `game` anywhere in its own tree: it has an `assets/` folder like the engine does, and the two only meet at runtime.

Nothing under the asset root is writable. That is not a rule the engine chose but the shape of the target platforms: Vita mounts the application read-only at `app0:` and Switch mounts `romfs:` read-only, so an asset API with a write side could not be implemented there anyway. State that has to survive a run (saves, user config) lives on a separate writable path, obtained from `SDL_GetPrefPath`, and will get its own class; it is not written yet, and it is deliberately not part of the asset API.

`fried.Assets.engine()` and `fried.Assets.game()` are macros. Each call is replaced, at compile time, by a single `fried.Filesystem.getAssetPath("<root>/<path>")` with the whole subpath already folded into one constant, so the mechanism costs nothing at runtime. What the macro does before folding is the point:

- It resolves the path against the source tree of the root it belongs to and fails the build if the file is not there, so a typo in an asset name is a compile error at the call site rather than a load that returns null on a platform nobody tested. The engine's own `assets/` is found relative to `src/fried/Assets.hx` on the classpath, so a game inherits it without configuring anything; the game's own is `assets/` relative to the directory `haxe` runs in, overridable with `-D fried-game-assets=<dir>`.
- It reads `Context.getLocalClass()` and refuses `game()` to any caller whose package starts with `fried`. This is what imposes the engine/game asymmetry: engine code has only `engine()` available to it, game code has both, and there is no second class, second classpath or runtime path inspection anywhere. The check is on who is compiling the call, which is exactly the thing being restricted.
- It rejects an absolute path, or one containing `..`, so neither root can be used to walk into the other.

Which of the two roots a call means is a value, not a prefix string: a private `AssetRoot` enum abstract in `Assets.hx`, in macro context only, following the same pattern as `fried.Key` and `fried.MouseButton`. The names `engine` and `game` are written once each, there, and everything else (the runtime prefix and which source directory to verify against) is derived from the value, so the two cannot drift apart.

Both take their path as a macro constant rather than a `String` expression, so a path assembled at runtime does not compile. That is deliberate: constant paths are what make the two checks above possible on every asset reference in the program. It is a restriction that can be relaxed later (by falling back to an unverified runtime resolution for non-constant expressions) without invalidating a single existing call, whereas the reverse would not be true.

The boundary is a guard rail, not a sandbox: `fried.Filesystem.getAssetPath()` is public, and has to be, since the macro expands at the call site and that call site is game code, so engine code that wanted to could still build a `game/` path by hand. What the macro buys is that it cannot happen by accident, and that it is visible in review as a deliberate bypass.

## Repository layout

```
FriedEngine/
  ARCHITECTURE.md
  README.md
  CMakeLists.txt      <- CMake entry point
  cmake/Hxcpp.cmake   <- locates hxcpp, compiles generated C++ & runtime
  native/             <- hand-written C++ glue wrapping SDL2
  src/fried/          <- engine Haxe source (Log, Time, Window, Application, Events, Input, Filesystem, Assets)
  assets/             <- the engine's own assets
  sandbox/            <- app validating the pipeline
  .vscode/            <- build/debug tasks for the sandbox
```

## Current status

See the roadmap and current stage in `README.md`.
