# Fried Engine

A game engine written primarily in [Haxe](https://haxe.org/), compiled to native C++ via [hxcpp](https://github.com/HaxeFoundation/hxcpp), on top of [SDL2](https://www.libsdl.org/) as the platform layer, with [CMake](https://cmake.org/) as the common build system across every target platform: Windows, Linux, macOS, and PlayStation Vita (via VitaSDK).

```
Haxe -> hxcpp -> generated C++ -> CMake -> toolchain/compiler -> executable
```

This repository contains **only the engine**. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for what is implemented and why.

## Project status

- [x] 1. Prove Haxe -> C++ -> CMake -> executable on PC (`sandbox/`)
- [x] 2. Integrate SDL2 (`sandbox/` opens and closes a real window)
- [x] 3. Minimal runtime (Application, Game Loop, Time, Window, Input, Events, Logging, Filesystem, Assets)
- [x] 4. Engine and game asset roots, read-only, verified at compile time
- [ ] 5. Renderer and resources (Texture, Shader, Sound, Music, Font)
- [ ] 6. Port the runtime to PlayStation Vita (VitaSDK toolchain, `app0:` asset root)
- [ ] 7. Real test game
- [ ] 8. Prove Fried Engine as a submodule in an external project
- [ ] 9. Define `project.fried`, and the writable user data path, which needs the game identity it declares

## Requirements (PC)

- [Haxe](https://haxe.org/) 4.3+
- [hxcpp](https://lib.haxe.org/p/hxcpp/) (`haxelib install hxcpp`)
- CMake 3.20+
- A C++17 compiler: GCC, Clang or MSVC
- SDL2 2.0+, plus SDL2_image, SDL2_mixer and SDL2_ttf, each with its CMake package config available to `find_package(... CONFIG)` (e.g. the distro's `SDL2-devel` or `libsdl2-dev` family of packages)

## Building the sandbox

The sandbox is a small Haxe program that exercises the engine's runtime. It is compiled to C++ by hxcpp, and that generated C++ is compiled and linked entirely by CMake, not by hxcpp's own build tool.

1. Generate the C++ from Haxe:

   ```sh
   cd sandbox
   haxe build.hxml
   cd ..
   ```

2. Configure and build with CMake, from the repo root:

   ```sh
   cmake -S . -B build
   cmake --build build
   ```

3. Run it:

   ```sh
   ./build/sandbox/fried_sandbox
   ```

A real SDL2 window opens and `fried.Application.run()` drives the game loop until the window is closed. The sandbox logs its base path, the assets it resolved from each asset root, and the window events it receives.

Verified working on Linux (GCC) with Haxe 4.3.7 and hxcpp 4.3.2. `cmake/Hxcpp.cmake`'s runtime source lists and compiler defines were derived from a real hxcpp build for that version; see the comment at the top of that file if you need to re-derive them.

## Assets

Game code resolves assets through `fried.Assets`, which has one member per asset root:

```haxe
Assets.engine("font.ttf")    // an asset shipped by the engine
Assets.game("sprite.png")    // an asset shipped by the game
```

Both are macros: the path is checked at compile time, and `game()` is not available to engine code. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full design.

## VS Code

Install the recommended extensions when prompted (C/C++, CMake Tools, Haxe & Neko), then:

- **Ctrl+Shift+B** runs the default **Build sandbox** task: it regenerates C++ from Haxe, configures CMake, and builds.
- **F5** builds and launches `fried_sandbox` under the debugger.

CMake Tools auto-configure on open is disabled on purpose: the sandbox's `CMakeLists.txt` needs `sandbox/build/cpp/` to already exist, so configuring must happen after the Haxe generation step. Use the build task, not the CMake Tools sidebar.

The debug config uses `cppdbg`/`gdb`, matching this repository's verified Linux/GCC setup; it will need an `lldb`/`cppvsdbg` variant once Windows/macOS are supported.

If you use the Flatpak build of VS Code, see [`docs/flatpak.md`](docs/flatpak.md): the sandbox cannot reach the host toolchain, and the tasks forward the commands to the host for you.
