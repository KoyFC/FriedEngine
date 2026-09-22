# Fried Engine Architecture

This document describes the **currently implemented** architecture of this repository. See `README.md` for the roadmap of what's coming.

## Scope of this repository

This repository is Fried Engine itself. Fried Build, Fried CLI and Fried Project Manager are separate tools, not yet built, that will live in their own repositories and consume this one as a dependency (a game project will pull this repo in as a pinned Git submodule). None of them exist yet.

## Build pipeline (implemented)

```
Haxe  --(hxcpp)-->  generated C++  --(CMake)-->  compiler  -->  executable
```

A minimal sandbox Haxe program is compiled to C++ by hxcpp (`haxe build.hxml`, using `-D no-compilation` to stop before hxcpp's own build tool would run), and that generated C++ is then compiled and linked purely by CMake — `cmake/Hxcpp.cmake` locates the `hxcpp` haxelib and compiles its runtime sources alongside the generated code, with no dependency on hxcpp's own `Build.xml`/`haxelib run hxcpp` build tool.

CMake is meant to be the build system for every platform this engine will target, but only the PC/CMake path above is actually implemented and verified so far.

## SDL2 (implemented, proof stage)

SDL2 is linked via CMake's own package config (`find_package(SDL2 CONFIG)`, `SDL2::SDL2`). `native/sdl_proof.cpp` is a single hand-written function that opens a window, runs a short frame loop, and closes it again; it's called from Haxe through the minimal extern in `sandbox/src/SdlProof.hx`. This only proves SDL2 links and runs through the pipeline. It is **not** the engine's Window/Renderer abstraction, which will replace it once built.

## Runtime (implemented so far)

`src/fried/` holds the engine's own Haxe code, package `fried`. So far:

- `fried.Log` — `info`/`warn`/`error`, printing to stdout/stderr.
- `fried.Time` — `start()`/`tick()`, exposing `deltaSeconds`, `elapsedSeconds`, `frameCount`.

Both are exercised from `sandbox/src/Main.hx`, which adds `src/` to its Haxe classpath alongside its own `sandbox/src/`. Application, Game Loop, Window, Input, Events, Filesystem and Assets aren't built yet.

## Repository layout

```
FriedEngine/
  ARCHITECTURE.md
  README.md
  CMakeLists.txt      <- CMake entry point
  cmake/Hxcpp.cmake   <- locates hxcpp, compiles generated C++ & runtime
  native/             <- hand-written C++ glue (currently: the SDL2 proof)
  src/fried/          <- engine Haxe source (Log, Time so far)
  sandbox/            <- app validating the pipeline
  .vscode/            <- build/debug tasks for the sandbox
```

## Current status

See the roadmap and current stage in `README.md`.
