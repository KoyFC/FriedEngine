# Fried Engine

A game engine written primarily in [Haxe](https://haxe.org/), compiled to native C++ via [hxcpp](https://github.com/HaxeFoundation/hxcpp), on top of [SDL2](https://www.libsdl.org/), with [CMake](https://cmake.org/) as the common build system across every target platform.

```
Haxe -> hxcpp -> generated C++ -> CMake -> toolchain/compiler -> executable
```

PC (verified on Linux/GCC), PlayStation Vita, Nintendo Switch and Nintendo 3DS are implemented. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for how it is put together and why.

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
- [x] 9. Game objects and components (`Scene`, `GameObject`, `Component`, `Transform`, `Sprite`, `Text`), drawn through a queue ordered by draw priority
- [ ] 10. Test Fried Engine as a submodule in an external project
- [ ] 11. Real test game
- [x] 12. Port the runtime to Nintendo Switch (devkitPro toolchain, `romfs:` asset root)
- [x] 13. Cameras (`Camera` as a component, one per scene, with screen space for anything a scene draws without one)
- [x] 14. Layer stack (ordered update and draw per renderer, with input events walking the stack from the top down)
- [x] 15. AABB collisions (`Collider` as a component, overlap and raycast queries over a scene, in `fried.physics`)
- [x] 16. Port the runtime to Nintendo 3DS (devkitPro toolchain, `romfs:` asset root, both screens, drawn through citro2d)

## Requirements

- [Haxe](https://haxe.org/) 4.3+ and [hxcpp](https://lib.haxe.org/p/hxcpp/) (`haxelib install hxcpp`)
- CMake 3.20+
- A C++17 compiler: GCC, Clang or MSVC
- SDL2 2.0+, plus SDL2_image, SDL2_mixer and SDL2_ttf, each with its CMake package config available to `find_package(... CONFIG)`

For a Vita build, [VitaSDK](https://vitasdk.org/) with `$VITASDK` set and its `bin/` on `PATH`, and the same four libraries from its package manager (`vdpm sdl2 sdl2_image sdl2_mixer sdl2_ttf`).

For a Switch build, [devkitPro](https://devkitpro.org/) with `$DEVKITPRO` set, and the same four libraries from its own (`dkp-pacman -S switch-dev switch-pkg-config switch-sdl2 switch-sdl2_image switch-sdl2_mixer switch-sdl2_ttf`). `switch-pkg-config` is not optional there: devkitPro's toolchain file refuses to configure without it, and it is how SDL2_image and SDL2_mixer are found, since devkitPro ships no CMake package config for either.

For a 3DS build, the same devkitPro install with `3ds-dev`, and the four libraries built from [`packaging/3ds/`](packaging/3ds/README.md), since devkitPro ships no SDL2 for the 3DS.

The Haxe side of the build is identical on every platform.

Windows is a planned target but is not yet supported. Nothing has been tested there, and VitaSDK has no native Windows install of its own, so building on Windows is likely going to need changes of your own.

## Building the sandbox

`sandbox/` is a small Haxe program that exercises the runtime, and it consumes the engine exactly the way a game does, so it is also the working example of a game's build.

```sh
cd sandbox && haxe build.hxml && cd ..
cmake -S . -B build
cmake --build build
./build/sandbox/fried_sandbox
```

A window opens on a small scene of game objects. WASD or the left stick moves a sprite through a world larger than the window, and a camera follows it: the wall and the row of posts scroll past, and the sprite passes behind or in front of the wall depending on which side of it it stands on, without anything being added to or removed from the scene. The posts carry colliders and the player cannot walk through them, sliding along one instead of stopping dead against it, while the wall carries none and stays the draw order demo. F5 draws every collider's bounds over the scene. Q and E zoom out and in, and zooming all the way out stops at the smallest zoom the camera allows rather than collapsing the view. A left click in it, or a touch on the front screen, logs where it landed in both screen and world coordinates, which collider the point is inside, and what a ray from the player to that point hits first, how far away and on which face.

The interface is a second scene with no camera of its own, so it draws in screen coordinates and stays put while the world moves, and it is pushed as a layer above the world, which is what keeps it on top rather than a hand-picked draw priority: two icons on the right show a component rotating its transform and another scrolling the region it draws from its texture, and a panel with two lines of text over it listing the controls. Those lines are `Text` components, and a third one under the right hand icons follows the scrolling region, changing as often as the number it shows does. A click or touch inside that panel is taken by the interface layer, so the world layer below it never logs that one, which is the same stack walked from the top down. Between the two sits a debug overlay in the bottom left corner, which is a layer that wraps no scene and draws itself: it reads out the frame count, the camera, the player's draw priority, the collider the player is being held by and, for each touch device, how many fingers are down and where the first one is. Every finger landing and lifting is logged with its id and its device, which on the Vita tells the front screen (0) from the rear pad (1). F3, or Select on a gamepad, turns it off and on without taking it off the stack, and F4, which the overlay itself handles, takes the interface off the stack and puts it back. The sandbox also loops its music, plays a sound on space or the south face button and pauses the music on M or the east one. Start quits, which is how the program ends on a console, where there is no window to close. The `vsyncEnabled` flag at the top of `main()` governs the renderer.

For a Vita build the generated C++ is the same, so only the CMake step changes:

```sh
cmake -S . -B build/vita -DCMAKE_TOOLCHAIN_FILE=$VITASDK/share/vita.toolchain.cmake
cmake --build build/vita
```

That produces `build/vita/sandbox/fried_sandbox.vpk`, which can be installed using VitaShell. Keep spaces out of both the project path and the build tree path: VitaSDK's packaging step passes them to `vita-pack-vpk` unquoted, and the failure surfaces as CMake failing to copy `<target>.vpk.out`.

A Switch build is the same again with devkitPro's toolchain file:

```sh
cmake -S . -B build/switch -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/Switch.cmake
cmake --build build/switch
```

That produces `build/switch/sandbox/fried_sandbox.nro`, which runs from hbmenu once copied anywhere under `sdmc:/switch/`. The assets travel inside the `.nro` as a romfs, so it is the only file to copy. Nothing it logs is visible on the console, so the scene on screen is the whole report a run gives.

A 3DS build is the same with the 3DS toolchain file:

```sh
cmake -S . -B build/3ds -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/3DS.cmake
cmake --build build/3ds
```

That produces `build/3ds/sandbox/fried_sandbox.3dsx`, which runs from the Homebrew Launcher once copied anywhere under `sdmc:/3ds/`, with its assets inside it as on the Switch. The scene draws on the top screen at 400x240, and the debug overlay moves to the bottom one, which the sandbox opens as a second window wherever `Window.maxCount` allows one. Touching the bottom screen therefore shows up in the overlay and the log rather than in the world, which is on the other screen. Sound needs the console's DSP firmware dumped to `sdmc:/3ds/dspfirm.cdc` (by DSP1 on a console; any file of that name satisfies Azahar), and without it the program runs silent. In Azahar, use its OpenGL renderer: on Vulkan the right half of the top screen flashes black.

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

`fried_add_game()` expects the layout those two files imply, relative to the project root: `build/cpp` for the generated C++, a `project.fried` declaring the game's identity, an `assets/` for the game's own assets, a `sce_sys/` for a Vita build, a `switch/icon.jpg` for a Switch one and a `3ds/icon.png` for a 3DS one. It then builds with the same commands the sandbox does.

## VS Code

Install the recommended extensions when prompted (C/C++, CMake Tools, Haxe & Neko). **Ctrl+Shift+B** runs the default build task, which regenerates the C++ from Haxe, configures CMake and builds; **F5** builds and launches under the debugger.

CMake Tools auto-configure on open is disabled on purpose, because configuring has to happen after the Haxe generation step. Use the build task, not the CMake Tools sidebar. The debug config uses `cppdbg`/`gdb`, matching the verified Linux/GCC setup.

IntelliSense follows the PC build, so the files only a console compiles, such as `native/graphics/renderer_citro.cpp`, show errors under it. For those, pick the **Nintendo 3DS** configuration (*C/C++: Select a Configuration*), which reads the flags from `build/3ds/compile_commands.json` and so needs that build tree configured first.

For the Flatpak build of VS Code, see [`docs/flatpak.md`](docs/flatpak.md).
