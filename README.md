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
- SDL2 2.0+, plus SDL2_image, SDL2_mixer and SDL2_ttf, each with its CMake package config available to `find_package(... CONFIG)` (e.g. the distro's `SDL2-devel`/`SDL2_image-devel`/`SDL2_mixer-devel`/`SDL2_ttf-devel` or `libsdl2-dev`/`libsdl2-image-dev`/`libsdl2-mixer-dev`/`libsdl2-ttf-dev` packages)

## Building the sandbox

The sandbox proves a small Haxe program that is compiled to C++ by hxcpp, and that generated C++ is compiled and linked into an executable entirely by CMake, not by hxcpp's own build tool.

The repository's `.vscode/` tasks run this same pipeline from the editor. If you use the Flatpak build of VS Code, see [`docs/flatpak.md`](docs/flatpak.md): the sandbox cannot reach the host toolchain, and the tasks forward the commands to the host for you.

1. Generate the C++ from Haxe (from `sandbox/`):

   ```sh
   cd sandbox
   haxe build.hxml
   cd ..
   ```

   This runs `build.hxml` (`-cp ../src -cp src -main Main -cpp build/cpp -D no-compilation`), pulling in the engine's own Haxe source from `../src` alongside the sandbox's own `src`, and stops after generating `sandbox/build/cpp/` without invoking hxcpp's own compiler/linker.

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
   [0 | 0.0s] [SUCCESS] Fried Engine sandbox initialized. Base path: .../build/sandbox/
   [0 | 0.0s] [INFO] Read README.md: 4642 bytes
   [0 | 0.0s] [INFO] Asset path: .../build/sandbox/assets/
   [0 | 0.0s] [SUCCESS] Found asset: sprite.png
   [0 | 0.0s] [SUCCESS] Found asset: beep.wav
   [0 | 0.0s] [SUCCESS] Found asset: font.ttf
   [0 | 0.0s] [SUCCESS] Window created: 640x480
   [1 | 0.75s] [INFO] Window focused
   [231 | 3.927s] [SUCCESS] Fried Engine sandbox run complete
   ```

   A real SDL2 window opens and `fried.Application.run()` drives the game loop (ticking `fried.Time`, pumping `fried.Events`, reporting clicks and window events) until the window is closed, then the window is destroyed and SDL shuts down. All of it goes through `fried.Application`/`fried.Window`/`fried.Events`/`fried.Time`/`fried.Input`/`fried.Platform`/`fried.Filesystem`/`fried.Log` (`src/fried/`), the engine's own Haxe code, not sandbox-only test code. The `Read README.md` line only appears when the sandbox is run from the repository root, since that path is relative to the working directory; the asset lines are resolved through `fried.Platform.getAssetPath()` and work from anywhere.

Verified working on Linux (GCC) with Haxe 4.3.7 and hxcpp 4.3.2. `cmake/Hxcpp.cmake`'s runtime/std source lists and compiler defines were derived from a real hxcpp build for that version; see the comment at the top of that file if you need to re-derive them for a different hxcpp version.

## Building and debugging from VS Code

Install the recommended extensions when prompted (C/C++, CMake Tools, Haxe & Neko), then:

- **Ctrl+Shift+B** (or Terminal → Run Build Task) runs the default **Build sandbox** task: it regenerates C++ from Haxe, configures CMake, and builds.
- **F5** builds (via the task above) and launches `fried_sandbox` under the debugger (breakpoints work in `sandbox/src/Main.hx`'s generated C++ and in `cmake/Hxcpp.cmake`-built sources).

CMake Tools auto-configure on opening the folder is disabled on purpose (`cmake.configureOnOpen: false` in `.vscode/settings.json`): the sandbox's `CMakeLists.txt` requires `sandbox/build/cpp/` to already exist, so configuring must happen after the Haxe generation step, not before it. Use the build task instead of the CMake Tools sidebar for a clean build.

The debug launch config (`.vscode/launch.json`) uses `cppdbg`/`gdb`, which matches this repository's currently-verified Linux/GCC setup; it will need a `lldb`/`cppvsdbg` variant once Windows/macOS support is added.
