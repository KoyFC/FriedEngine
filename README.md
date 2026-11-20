# Fried Engine

A game engine written primarily in [Haxe](https://haxe.org/), compiled to native C++ via [hxcpp](https://github.com/HaxeFoundation/hxcpp), on top of [SDL2](https://www.libsdl.org/) (or [gint](https://git.planet-casio.com/Lephenixnoir/gint) on the Casio fx-CG50 and [libnds](https://github.com/devkitPro/libnds) on the Nintendo DS), with [CMake](https://cmake.org/) as the common build system across every target platform.

```
Haxe -> hxcpp -> generated C++ -> CMake -> toolchain/compiler -> executable
```

PC (verified on Linux with GCC, and on Windows built with MSVC or MinGW-w64 on Windows, or with MinGW-w64 from Linux), PlayStation Vita, Nintendo Switch, Nintendo 3DS, the Casio fx-CG50 graphing calculator and the web browser are implemented. The Nintendo DS runs the sandbox on both screens, with its buttons as a gamepad, its touchscreen as the bottom window's, and its sounds and music. See [Architecture](https://koyfc.github.io/FriedEngine/architecture/) for how it is put together and why.

This repository is the engine alone, and it is not the starting point for a game. A game lives in its own repository, pins the engine as a Git submodule, and builds it as part of its own build. The recommended way to start one is [Fried Project Manager](https://github.com/KoyFC/FriedProjectManager), which writes a project that already has the engine as a submodule and builds and runs as it comes out. [Using the engine in a game](https://koyfc.github.io/FriedEngine/getting-started/using-in-a-game/) is the same layout by hand. Cloning this repository on its own is for working on the engine itself, and `sandbox/` is its test program rather than a template.

## Documentation

The documentation is at <https://koyfc.github.io/FriedEngine/>:

- [Installing](https://koyfc.github.io/FriedEngine/getting-started/installing/)
- [Building](https://koyfc.github.io/FriedEngine/getting-started/building/)
- [Using the engine in a game](https://koyfc.github.io/FriedEngine/getting-started/using-in-a-game/)
- [Architecture](https://koyfc.github.io/FriedEngine/architecture/)
- [API reference](https://koyfc.github.io/FriedEngine/api/)

On Linux, with everything in [Installing](https://koyfc.github.io/FriedEngine/getting-started/installing/) set up, the sandbox builds and runs with:

```sh
cd sandbox && haxe build.hxml && cd ..
cmake -S . -B build
cmake --build build
./build/sandbox/fried_sandbox
```
