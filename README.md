# Fried Engine

A game engine written primarily in [Haxe](https://haxe.org/), compiled to native C++ via [hxcpp](https://github.com/HaxeFoundation/hxcpp), on top of [SDL2](https://www.libsdl.org/), with [CMake](https://cmake.org/) as the common build system across every target platform.

```
Haxe -> hxcpp -> generated C++ -> CMake -> toolchain/compiler -> executable
```

PC (verified on Linux/GCC) and PlayStation Vita are implemented. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for how it is put together and why.

This repository is the engine alone, and it is not the starting point for a game. A game lives in its own repository, pins the engine as a Git submodule, and builds it as part of its own build. The recommended way to start one is [Fried Project Manager](https://github.com/KoyFC/FriedProjectManager), which writes a project that already has the engine as a submodule and builds and runs as it comes out. [Using the engine in a game](#using-the-engine-in-a-game) is the same layout by hand. Cloning this repository on its own is for working on the engine itself, and `sandbox/` is its test program rather than a template.

## Project status

- [x] 1. Test Haxe -> C++ -> CMake -> executable on PC (`sandbox/`)
- [x] 2. Integrate SDL2 (`sandbox/` opens and closes a real window)
- [x] 3. Minimal runtime (Application, Game Loop, Time, Window, Input, Events, Logging, Filesystem, Assets)
- [x] 4. Engine and game asset roots, read-only, verified at compile time
- [x] 5. Renderer and resources (`Renderer`, `Texture`, `Font`, `Sound`, `Music`)
- [x] 6. Port the runtime to PlayStation Vita (VitaSDK toolchain, `app0:` asset root)
- [x] 7. Define `project.fried`, and the writable user data path, which needs the game identity it declares
- [x] 8. Fried Project Manager: create the basic structure of a new game project
- [ ] 9. Test Fried Engine as a submodule in an external project
- [ ] 10. Real test game

## Requirements

- [Haxe](https://haxe.org/) 4.3+ and [hxcpp](https://lib.haxe.org/p/hxcpp/) (`haxelib install hxcpp`)
- CMake 3.20+
- A C++17 compiler: GCC, Clang or MSVC
- SDL2 2.0+, plus SDL2_image, SDL2_mixer and SDL2_ttf, each with its CMake package config available to `find_package(... CONFIG)`

For a Vita build, [VitaSDK](https://vitasdk.org/) with `$VITASDK` set and its `bin/` on `PATH`, and the same four libraries from its package manager (`vdpm sdl2 sdl2_image sdl2_mixer sdl2_ttf`). The Haxe side of the build is identical on every platform.

Windows is a planned target but is not yet supported. Nothing has been tested there, and VitaSDK has no native Windows install of its own, so building on Windows is likely going to need changes of your own.

## Building the sandbox

`sandbox/` is a small Haxe program that exercises the runtime, and it consumes the engine exactly the way a game does, so it is also the working example of a game's build.

```sh
cd sandbox && haxe build.hxml && cd ..
cmake -S . -B build
cmake --build build
./build/sandbox/fried_sandbox
```

A window opens and the sandbox draws a sprite and a line of text, loops its music, plays a sound on space and pauses the music on M.

For a Vita build the generated C++ is the same, so only the CMake step changes:

```sh
cmake -S . -B build/vita -DCMAKE_TOOLCHAIN_FILE=$VITASDK/share/vita.toolchain.cmake
cmake --build build/vita
```

That produces `build/vita/sandbox/fried_sandbox.vpk`, which can be installed using VitaShell. Keep spaces out of both the project path and the build tree path: VitaSDK's packaging step passes them to `vita-pack-vpk` unquoted, and the failure surfaces as CMake failing to copy `<target>.vpk.out`.

## Using the engine in a game

[Fried Project Manager](https://github.com/KoyFC/FriedProjectManager) writes all of this for you, and that is the recommended route. What follows is what it produces, for a project set up by hand or for reading what a generated one contains.

The engine is consumed as a Git submodule:

```sh
git submodule add https://github.com/KoyFC/FriedEngine.git engine
```

The game's `CMakeLists.txt` needs two lines for it:

```cmake
cmake_minimum_required(VERSION 3.20)
project(MyGame LANGUAGES CXX)

include(${CMAKE_CURRENT_SOURCE_DIR}/engine/cmake/FriedEngine.cmake)

fried_add_game(my_game)
```

and its `build.hxml` points at the submodule's source:

```
-cp engine/src
-cp src
-main Main
-cpp build/cpp
-D no-compilation
```

`fried_add_game()` expects the layout those two files imply, relative to the project root: `build/cpp` for the generated C++, a `project.fried` declaring the game's identity, an `assets/` for the game's own assets, and a `sce_sys/` for a Vita build. It then builds with the same commands the sandbox does.

## VS Code

Install the recommended extensions when prompted (C/C++, CMake Tools, Haxe & Neko). **Ctrl+Shift+B** runs the default build task, which regenerates the C++ from Haxe, configures CMake and builds; **F5** builds and launches under the debugger.

CMake Tools auto-configure on open is disabled on purpose, because configuring has to happen after the Haxe generation step. Use the build task, not the CMake Tools sidebar. The debug config uses `cppdbg`/`gdb`, matching the verified Linux/GCC setup.

For the Flatpak build of VS Code, see [`docs/flatpak.md`](docs/flatpak.md).
