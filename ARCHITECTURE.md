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

SDL2 is linked via CMake's own package config (`find_package(SDL2 CONFIG)`, `SDL2::SDL2`). `native/` holds small, hand-written C glue files that wrap the specific SDL2 calls the engine needs (`application.cpp`: `SDL_Init`/`SDL_Quit`; `events.cpp`: polling for `SDL_QUIT`, also forwarding `SDL_MOUSEWHEEL` events to `mouse.cpp` since SDL2 only reports the wheel through events, not a poll-able state; `window.cpp`: creating/destroying an `SDL_Window`, tracked by integer handle so no SDL pointer types cross into Haxe; `input.cpp`: querying `SDL_GetKeyboardState`; `mouse.cpp`: querying `SDL_GetMouseState` and accumulating wheel deltas reported by `events.cpp`). Each is bound to Haxe through a small `extern class` in the matching `fried.*` class. Game code never sees SDL2 directly, only `fried.Application`/`fried.Window`/`fried.Events`/`fried.Input`.

## Runtime (implemented so far)

`src/fried/` holds the engine's own Haxe code, package `fried`:

- `fried.Log`: `info`/`warn`/`error`, printing to stdout/stderr.
- `fried.Time`: `start()`/`tick()`, exposing `deltaSeconds`, `elapsedSeconds`, `frameCount`.
- `fried.Window`: creates/destroys an SDL window, exposes `width`/`height`. A pure platform primitive: it does not own or know about a renderer (see the Window/Renderer decoupling this repo's design follows once a Renderer exists).
- `fried.Application`: owns the SDL lifecycle (`init`/`shutdown`) and the game loop itself: `run(update)` loops while `running` is true, pumping events (via `fried.Events`), ticking `fried.Time`, and ending the frame for `fried.Input` (in that order) each iteration; `quit()` stops it.
- `fried.Events`: `pump():Bool`, true if the application should quit (currently: an `SDL_QUIT` event was seen).
- `fried.Input`: keyboard and mouse, both following the same three-state naming (deliberately matching Unity's `GetKey`/`GetKeyDown`/`GetKeyUp`, not the more common `IsKeyDown`-means-held convention): `isKeyPressed`/`isButtonPressed` (true every frame the key/button is held, from the frame it went down through the frame before it comes back up), `isKeyDown`/`isButtonDown` (true only on the single frame it went down), `isKeyReleased`/`isButtonReleased` (true only on the single frame it came back up). Both compare SDL's live state (kept current as a side effect of `fried.Events.pump()`'s `SDL_PollEvent` calls) against a previous-frame snapshot `fried.Application.run()` refreshes once per frame. `fried.Key` is an enum abstract over SDL's stable `SDL_SCANCODE_*` values (letters, digits, F1-F12, arrows, common control/modifier keys) and `fried.MouseButton` likewise over SDL's button ids (`Left`/`Middle`/`Right`), keeping SDL2 constants out of game code. Mouse also exposes `mouseX`/`mouseY` (position) and `scrollX`/`scrollY` (wheel delta accumulated this frame, reset every frame); no gamepad yet.

All exercised together from `sandbox/src/Main.hx`, which adds `src/` to its Haxe classpath alongside its own `sandbox/src/`. Not built yet: Filesystem, Assets, Renderer.

## Repository layout

```
FriedEngine/
  ARCHITECTURE.md
  README.md
  CMakeLists.txt      <- CMake entry point
  cmake/Hxcpp.cmake   <- locates hxcpp, compiles generated C++ & runtime
  native/             <- hand-written C++ glue wrapping SDL2
  src/fried/          <- engine Haxe source (Log, Time, Window, Application, Events, Input)
  sandbox/            <- app validating the pipeline
  .vscode/            <- build/debug tasks for the sandbox
```

## Current status

See the roadmap and current stage in `README.md`.
