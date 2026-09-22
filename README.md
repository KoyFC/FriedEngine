# Fried Engine

A game engine written primarily in [Haxe](https://haxe.org/), compiled to native C++ via [hxcpp](https://github.com/HaxeFoundation/hxcpp), on top of [SDL2](https://www.libsdl.org/) as the platform layer, with [CMake](https://cmake.org/) as the common build system across every target platform: Windows, Linux, macOS, and PlayStation Vita (via VitaSDK).

This repository contains **only the engine**. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for why, and for the full ecosystem architecture.

## Build pipeline

```
Haxe -> hxcpp -> generated C++ -> CMake -> toolchain/compiler -> executable
```

## Project status

- [x] 1. Prove Haxe -> C++ -> CMake -> executable on PC (`sandbox/`)
- [x] 2. Integrate SDL2 (`sandbox/` opens and closes a real window)
- [ ] 3. Minimal runtime (Application, Game Loop, Time, Window, Input, Events, Logging, Filesystem, Assets)
- [ ] 4. Hybrid Filesystem and Asset Pipeline
- [ ] 5. Renderer and resources (Texture, Shader, Sound, Music, Font)
- [ ] 6. Real test game
- [ ] 7. Prove Fried Engine as a submodule in an external project
- [ ] 8. Define `project.fried`

## Build requirements (PC)

- [Haxe](https://haxe.org/) 4.3+
- [hxcpp](https://lib.haxe.org/p/hxcpp/) (`haxelib install hxcpp`)
- CMake 3.20+
- A C++17 compiler: GCC, Clang or MSVC
- SDL2 2.0+, with its CMake package config available to `find_package(SDL2 CONFIG)` (e.g. the distro's `SDL2-devel`/`libsdl2-dev` package)

## Building the sandbox

The sandbox proves a small Haxe program that is compiled to C++ by hxcpp, and that generated C++ is compiled and linked into an executable entirely by CMake, not by hxcpp's own build tool.

1. Generate the C++ from Haxe (from `sandbox/`):

   ```sh
   cd sandbox
   haxe build.hxml
   cd ..
   ```

   This runs `haxe -cp src -main Main -cpp build/cpp -D no-compilation`, which stops after generating `sandbox/build/cpp/` and does **not** invoke hxcpp's own compiler/linker.

2. Configure and build with CMake (from the repo root):

   ```sh
   cmake -S . -B build
   cmake --build build
   ```

   `cmake/Hxcpp.cmake` locates the `hxcpp` haxelib (via `haxelib path hxcpp`) and compiles `sandbox/build/cpp/` together with the hxcpp runtime sources, using the same defines hxcpp's own build tool would use.

3. Run it:

   ```sh
   ./build/sandbox/fried_sandbox
   ```

   Expected output:

   ```
   Fried Engine sandbox pipeline OK (1..10 sum = 55)
   Fried Engine SDL2 proof OK (window opened, ran, closed)
   ```

   A real SDL2 window briefly opens and closes on its own — that's the step 2 proof (`native/sdl_proof.cpp`, bound from Haxe via `sandbox/src/SdlProof.hx`). It's a minimal hand-written glue function, not the engine's real SDL2 abstraction, which comes in later steps.

Verified working on Linux (GCC) with Haxe 4.3.7 and hxcpp 4.3.2. `cmake/Hxcpp.cmake`'s runtime/std source lists and compiler defines were derived from a real hxcpp build for that version; see the comment at the top of that file if you need to re-derive them for a different hxcpp version.

## Building and debugging from VS Code

Install the recommended extensions when prompted (C/C++, CMake Tools, Haxe & Neko), then:

- **Ctrl+Shift+B** (or Terminal → Run Build Task) runs the default **Build sandbox** task: it regenerates C++ from Haxe, configures CMake, and builds.
- **F5** builds (via the task above) and launches `fried_sandbox` under the debugger (breakpoints work in `sandbox/src/Main.hx`'s generated C++ and in `cmake/Hxcpp.cmake`-built sources).

CMake Tools auto-configure on opening the folder is disabled on purpose (`cmake.configureOnOpen: false` in `.vscode/settings.json`): the sandbox's `CMakeLists.txt` requires `sandbox/build/cpp/` to already exist, so configuring must happen after the Haxe generation step, not before it. Use the build task instead of the CMake Tools sidebar for a clean build.

The debug launch config (`.vscode/launch.json`) uses `cppdbg`/`gdb`, which matches this repository's currently-verified Linux/GCC setup; it will need a `lldb`/`cppvsdbg` variant once Windows/macOS support is added.
