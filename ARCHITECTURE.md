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

SDL2 is linked via CMake's own package config (`find_package(SDL2 CONFIG)`, `SDL2::SDL2`), together with its three companion libraries, SDL2_image, SDL2_mixer and SDL2_ttf, each found and linked the same way. They are initialized and torn down alongside SDL itself in `application.cpp` (`IMG_Init` for PNG, `TTF_Init`, `Mix_OpenAudio` at 44100Hz stereo), so that a failure to bring one up fails `fried.Application.init()` rather than surfacing later, at the first load. Nothing loads through them yet: `Texture`/`Sound`/`Music`/`Font` arrive with the Renderer. `native/` holds small, hand-written C glue files that wrap the specific SDL2 calls the engine needs (`application.cpp`: `SDL_Init`/`SDL_Quit`; `events.cpp`: polling for `SDL_QUIT`, also forwarding `SDL_MOUSEWHEEL` events to `mouse.cpp` since SDL2 only reports the wheel through events, not a poll-able state, and translating `SDL_WINDOWEVENT` into a small queue of window events that Haxe drains once SDL polling is over; `window.cpp`: creating/destroying an `SDL_Window`, tracked by integer handle so no SDL pointer types cross into Haxe, resolving SDL's own window id back to that handle for `events.cpp`, and repainting every live window's surface once per frame; `input.cpp`: querying `SDL_GetKeyboardState`; `platform.cpp`: `SDL_GetBasePath` and the asset root derived from it; `mouse.cpp`: querying `SDL_GetMouseState` and accumulating wheel deltas reported by `events.cpp`). Each is bound to Haxe through a small `extern class` in the matching `fried.*` class. Game code never sees SDL2 directly, only `fried.Application`/`fried.Window`/`fried.Events`/`fried.Input`.

## Runtime (implemented so far)

`src/fried/` holds the engine's own Haxe code, package `fried`:

- `fried.Log`: `info`/`warn`/`error`, printing to stdout/stderr.
- `fried.Time`: `start()`/`tick()`, exposing `deltaSeconds`, `elapsedSeconds`, `frameCount`.
- `fried.Window`: creates/destroys an SDL window (resizable), exposes `width`/`height`, and exposes the window's events as assignable callbacks: `onClose`, `onResize(width, height)` and `onFocusChanged(focused)`, all null until the game sets them. Resizes are reported from SDL's `SDL_WINDOWEVENT_SIZE_CHANGED` rather than `SDL_WINDOWEVENT_RESIZED`, since SDL only sends the latter for size changes the user or window manager caused. Reacting to a resize is optional: `width`/`height` always query SDL for the live size, so code that simply reads them every frame stays correct without touching the callbacks at all. On Wayland a window only takes its new size once the client commits a buffer at that size, so `fried.Application`'s loop presents every window once per frame (`native/window.cpp`'s `fried_window_present_all`, currently just a black fill); without it the user cannot resize the window at all, since nothing the engine draws ever reaches the compositor after the first frame. This is a placeholder for the Renderer, which will own presentation once it exists and cannot share a window with `SDL_GetWindowSurface`. A pure platform primitive: it does not own or know about a renderer (see the Window/Renderer decoupling this repo's design follows once a Renderer exists).
- `fried.Application`: owns the SDL lifecycle (`init`/`shutdown`) and the game loop itself: `run(update)` loops while `running` is true, pumping events (via `fried.Events`), ticking `fried.Time`, running `update`, presenting the windows and ending the frame for `fried.Input` (in that order) each iteration; `quit()` stops it. `targetFps` (60 by default, 0 to uncap) makes the loop sleep out whatever is left of the frame's budget, since nothing else in the engine blocks yet: uncapped, the loop spins a core at 100%. `Sys.sleep` only guarantees a minimum, so the real rate settles slightly under the target (measured: 59.2fps at 60, using around 5% of a core); hitting a target exactly needs vsync, which arrives with the Renderer.
- `fried.Events`: `pump():Bool`, true if the application should quit (currently: an `SDL_QUIT` event was seen). It also drains the window events `native/events.cpp` queued and dispatches each one to the callbacks of the `fried.Window` it belongs to, found through a registry `fried.Window` keeps by handle. Draining happens after the native pump has emptied SDL's queue, so a callback never runs while SDL state is still mid-update. Closing the last window needs no callback to work: SDL raises `SDL_QUIT` for it, which already ends the loop.
- `fried.Input`: keyboard and mouse, both following the same three-state naming (deliberately matching Unity's `GetKey`/`GetKeyDown`/`GetKeyUp`, not the more common `IsKeyDown`-means-held convention): `isKeyPressed`/`isButtonPressed` (true every frame the key/button is held, from the frame it went down through the frame before it comes back up), `isKeyDown`/`isButtonDown` (true only on the single frame it went down), `isKeyReleased`/`isButtonReleased` (true only on the single frame it came back up). Both compare SDL's live state (kept current as a side effect of `fried.Events.pump()`'s `SDL_PollEvent` calls) against a previous-frame snapshot `fried.Application.run()` refreshes once per frame. `fried.Key` is an enum abstract over SDL's stable `SDL_SCANCODE_*` values (letters, digits, F1-F12, arrows, common control/modifier keys) and `fried.MouseButton` likewise over SDL's button ids (`Left`/`Middle`/`Right`), keeping SDL2 constants out of game code. Mouse also exposes `mouseX`/`mouseY` (position) and `scrollX`/`scrollY` (wheel delta accumulated this frame, reset every frame); no gamepad yet.
- `fried.Platform`: `basePath` (SDL's `SDL_GetBasePath()`, the directory the executable lives in) and the asset root, as `assetPath` plus `getAssetPath(relativePath)` which prefixes a path with it. `native/platform.cpp` is the single place that decides where a platform keeps its assets (currently `<basePath>assets/` everywhere); platforms with a fixed mount point, such as Vita's `app0:/` or Switch's `romfs:/`, change that one function and nothing above it. Engine and game code never branch on platform to open an asset, and never build a path out of `basePath` by hand.
- `fried.Filesystem`: `exists(path)`/`readBytes(path)`, a thin wrapper over hxcpp's own `sys.FileSystem`/`sys.io.File` rather than native glue, since (unlike windowing/input) the `cpp` target already implements these natively and cross-platform-enough for the PC scope currently verified. The wrapper exists so the implementation can be swapped for native/SDL glue later without touching call sites, if a target platform's `sys` support proves inadequate (e.g. Vita/Switch). Scoped to generic, non-media data (config, level data, `project.fried`); image/audio/font resources will not go through it. SDL's own libraries for those (SDL_image, SDL_mixer, SDL_ttf) load directly from a path and decode the format themselves, so `Texture`/`Sound`/`Music`/`Font` will each be their own wrapper over the matching SDL library, independent of `Filesystem`.

All exercised together from `sandbox/src/Main.hx`, which adds `src/` to its Haxe classpath alongside its own `sandbox/src/`. The sandbox keeps a small PNG, WAV and TTF in `sandbox/assets/`, all three generated for this repository so nothing third-party is vendored (the font is a placeholder that draws every printable ASCII character as the same filled box, enough to prove `TTF_OpenFont` gets a real file), copied next to the executable by CMake after linking (the asset root is resolved from `SDL_GetBasePath()`, so the assets have to sit beside the binary, not beside the sources); it checks each of them through `fried.Platform.getAssetPath()` at startup. Not built yet: the asset pipeline itself, Renderer.

## Repository layout

```
FriedEngine/
  ARCHITECTURE.md
  README.md
  CMakeLists.txt      <- CMake entry point
  cmake/Hxcpp.cmake   <- locates hxcpp, compiles generated C++ & runtime
  native/             <- hand-written C++ glue wrapping SDL2
  src/fried/          <- engine Haxe source (Log, Time, Window, Application, Events, Input, Platform, Filesystem)
  sandbox/            <- app validating the pipeline
  .vscode/            <- build/debug tasks for the sandbox
```

## Current status

See the roadmap and current stage in `README.md`.
