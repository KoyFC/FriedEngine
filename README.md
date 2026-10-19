# Fried Engine

A game engine written primarily in [Haxe](https://haxe.org/), compiled to native C++ via [hxcpp](https://github.com/HaxeFoundation/hxcpp), on top of [SDL2](https://www.libsdl.org/) (or [gint](https://git.planet-casio.com/Lephenixnoir/gint) on the Casio fx-CG50), with [CMake](https://cmake.org/) as the common build system across every target platform.

```
Haxe -> hxcpp -> generated C++ -> CMake -> toolchain/compiler -> executable
```

PC (verified on Linux with GCC, and on Windows built with MSVC on Windows or with MinGW-w64 from Linux), PlayStation Vita, Nintendo Switch, Nintendo 3DS and the Casio fx-CG50 graphing calculator are implemented. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for how it is put together and why.

This repository is the engine alone, and it is not the starting point for a game. A game lives in its own repository, pins the engine as a Git submodule, and builds it as part of its own build. The recommended way to start one is [Fried Project Manager](https://github.com/KoyFC/FriedProjectManager), which writes a project that already has the engine as a submodule and builds and runs as it comes out. [Using the engine in a game](#using-the-engine-in-a-game) is the same layout by hand. Cloning this repository on its own is for working on the engine itself, and `sandbox/` is its test program rather than a template.

## Requirements

- [Haxe](https://haxe.org/) 4.3+ and [hxcpp](https://lib.haxe.org/p/hxcpp/) (`haxelib install hxcpp`)
- CMake 3.20+
- A C++17 compiler: GCC, Clang or MSVC

SDL2 and its companion libraries do not need to be installed for a PC build. The first configure of a build tree downloads SDL2, SDL2_image, SDL2_mixer and SDL2_ttf and builds them into it, so it needs an internet connection and takes noticeably longer than later ones. On Linux, SDL2 is built against the display and audio systems it finds, so the development headers for X11, Wayland and PulseAudio need to be installed (on Fedora: `libX11-devel libXext-devel wayland-devel libxkbcommon-devel pulseaudio-libs-devel`). PulseAudio's are enough on a PipeWire system, which serves PulseAudio clients. To link SDL2 2.0+, SDL2_image, SDL2_mixer and SDL2_ttf already installed instead, each with its CMake package config, configure with `-DFRIED_SYSTEM_SDL2=ON`.

For a Windows build from Linux, [MinGW-w64](https://www.mingw-w64.org/)'s GCC (`mingw64-gcc-c++` on Fedora), and [Wine](https://www.winehq.org/) to run the result there. SDL2 is built for Windows from source just as it is for Linux. The toolchain file looks for the MinGW-w64 libraries where Fedora, Debian and Arch put them, and `-DFRIED_MINGW_SYSROOT=<path>` points it anywhere else.

For a Vita build, [VitaSDK](https://vitasdk.org/) with `$VITASDK` set and its `bin/` on `PATH`, and the same four libraries from its package manager (`vdpm sdl2 sdl2_image sdl2_mixer sdl2_ttf`).

For a Switch build, [devkitPro](https://devkitpro.org/) with `$DEVKITPRO` set, and the same four libraries from its own (`dkp-pacman -S switch-dev switch-pkg-config switch-sdl2 switch-sdl2_image switch-sdl2_mixer switch-sdl2_ttf`). `switch-pkg-config` is not optional there: devkitPro's toolchain file refuses to configure without it, and it is how SDL2_image and SDL2_mixer are found, since devkitPro ships no CMake package config for either.

For a 3DS build, the same devkitPro install with `3ds-dev`, and the four libraries built from [`packaging/3ds/`](packaging/3ds/README.md), since devkitPro ships no SDL2 for the 3DS.

For an fx-CG50 build, the [fxSDK](https://git.planet-casio.com/Lephenixnoir/fxsdk) with gint and its `sh-elf-gcc` and libstdc++, and that libstdc++ rebuilt with exceptions by [`packaging/cg50/`](packaging/cg50/README.md), since the fxSDK builds it without them. No SDL2 is involved: gint is the whole platform there.

The Haxe side of the build is identical on every platform.

Building for PC on Windows itself is covered in [Building on Windows](#building-on-windows). Console builds have only been tested from Linux, and VitaSDK has no native Windows install of its own, so building one on Windows is likely going to need changes of your own.

## Building the sandbox

`sandbox/` is a small Haxe program that exercises the runtime, and it consumes the engine exactly the way a game does, so it is also the working example of a game's build.

```sh
cd sandbox && haxe build.hxml && cd ..
cmake -S . -B build
cmake --build build
./build/sandbox/fried_sandbox
```

A window opens on a small scene of game objects. WASD, the arrow keys or the left stick move a sprite through a world larger than the window, and a camera follows it: the wall and the row of posts scroll past, and the sprite passes behind or in front of the wall depending on which side of it it stands on, without anything being added to or removed from the scene. The posts carry colliders and the player cannot walk through them, sliding along one instead of stopping dead against it, while the wall carries none and stays the draw order demo. F5 draws every collider's bounds over the scene. Q and E, F1 and F2, or the L and R shoulder buttons, zoom out and in, and zooming all the way out stops at the smallest zoom the camera allows rather than collapsing the view. A left click in it, or a touch on the front screen, logs where it landed in both screen and world coordinates, which collider the point is inside, and what a ray from the player to that point hits first, how far away and on which face. Its `project.fried` sets an `expand` display designed at 640x480, so a wider screen or a resized window shows more of the world rather than black bars, and the 3DS overrides it to `default`, since text laid out for 480 lines is not legible at half that. The camera's zoom keeps the world 480 units tall on every screen, so the 3DS still shows as much of it as the others while its interface stays at native size.

The interface is a second scene with no camera of its own, so it draws in screen coordinates and stays put while the world moves, and it is pushed as a layer above the world, which is what keeps it on top rather than a hand-picked draw priority: two icons on the right show a component rotating its transform and another scrolling the region it draws from its texture, and a panel with two lines of text over it listing the controls. Those lines are `Text` components, and a third one under the right hand icons follows the scrolling region, changing as often as the number it shows does. A click or touch inside that panel is taken by the interface layer, so the world layer below it never logs that one, which is the same stack walked from the top down. Between the two sits a debug overlay in the bottom left corner, which takes the whole bottom screen on a 3DS: it reads out the frame count, the camera, the player's draw priority, the collider the player is being held by and, for each touch device, how many fingers are down and where the first one is. Every finger landing and lifting is logged with its id and its device, which on the Vita tells the front screen (0) from the rear pad (1). Under the readout, `Button`s do what the keys below do, by touch or by mouse, each showing whether what it toggles is on. F3, or Select on a gamepad, turns it off and on without taking it off the stack, and F4, which the overlay itself handles, takes the interface off the stack and puts it back. The sandbox also loops its music, plays a sound on space, Enter or the south face button and pauses the music on M, F6 or the east one. Escape or Start quits, which is how the program ends on a console or the calculator, where there is no window to close. Each action has a key the calculator's keypad has too, which is what the arrows, the function keys, Enter and Escape are there for. On a screen under 240 lines tall the interface uses a smaller font, and the debug overlay reads out the frame rate on every platform. The `vsyncEnabled` flag at the top of `main()` governs the renderer.

A Windows build from Linux uses the engine's own MinGW-w64 toolchain file:

```sh
cmake -S . -B build/windows -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/mingw-w64.cmake
cmake --build build/windows
wine build/windows/sandbox/fried_sandbox.exe
```

That produces `build/windows/sandbox/fried_sandbox.exe` with an `assets/` folder next to it, and the two are the whole game: the executable is linked statically, so it needs no DLL beyond the ones Windows itself ships. A Release build opens no console window, so its log is only visible from a Debug one (`-DCMAKE_BUILD_TYPE=Debug`) or under Wine, which prints it to the terminal either way.

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

An fx-CG50 build is the same with the fxSDK's toolchain file, which sits under the fxSDK's install prefix (`~/.local` by default):

```sh
cmake -S . -B build/cg50 -DCMAKE_TOOLCHAIN_FILE=$HOME/.local/lib/cmake/fxsdk/FXCG50.cmake
cmake --build build/cg50
```

That produces `build/cg50/sandbox/fried_sandbox.g3a` and, next to it, a `Fried Sandbox/` folder holding the assets. With the calculator connected over USB in its storage mode, both go at the root of its storage memory, and the add-in then appears in the main menu. The assets stay outside the `.g3a`, which holds at most 2 MB, and audio is left out of them, since the calculator cannot play it; the game still loads and plays its sounds, silently. The screen is 396x224 and the keypad is the keyboard: the digits, the arrows, EXE as Enter, EXIT as Escape, DEL as Backspace, F1 to F6, SHIFT and ALPHA are those keys, the twelve keys above the digits are the letters A to L that ALPHA types with them, and the point key is Space. MENU always leaves for the calculator's main menu, as it does in every add-in, and the game sees its window lose and regain focus around it. Text set in a font too large for the calculator's memory, as the sandbox's is, falls back to the calculator's own pixel font. Everything is drawn by the CPU, so the sandbox runs at around 43 frames a second with neither of its overlays, 25 with one of them and 19 with both, and writing user data pauses the game for a moment, since the calculator's storage is slow to write.

## Building on Windows

Everything a PC build needs on Windows, from a machine with nothing installed:

1. [Git for Windows](https://git-scm.com/download/win), to clone the engine and, in a game, its submodule.
2. [Haxe](https://haxe.org/download/) 4.3 or later, from its Windows installer, which puts `haxe` and `haxelib` on `PATH` and sets up the haxelib repository. Then, in a new terminal, `haxelib install hxcpp`.
3. [CMake](https://cmake.org/download/) 3.20 or later, from its Windows installer, choosing to add it to `PATH` for the current user or all users.
4. [Build Tools for Visual Studio](https://visualstudio.microsoft.com/visual-cpp-build-tools/) 2022 or later, with the **Desktop development with C++** workload, which brings MSVC and the Windows SDK. Visual Studio Community with the same workload works too.

SDL2 needs no installing, as on Linux: the first configure downloads and builds it, so it needs an internet connection and takes a few minutes. From a regular terminal, PowerShell or `cmd`:

```sh
git clone https://github.com/KoyFC/FriedEngine.git
cd FriedEngine/sandbox
haxe build.hxml
cd ..
cmake -S . -B build
cmake --build build --config Release
build/sandbox/Release/fried_sandbox.exe
```

CMake finds Visual Studio by itself, so there is no developer prompt to open first. Its generator builds every configuration into its own folder and takes the configuration at build time rather than at configure time, which is why the build passes `--config` and the executable lands under `Release/`. That folder and the `assets/` folder in it are the whole game: the C++ runtime is linked statically like SDL2, so it needs no Visual C++ redistributable. A Release build opens no console window, and `--config Debug` builds one that does, under `build/sandbox/Debug/`, for reading the log.

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

`fried_add_game()` expects the layout those two files imply, relative to the project root: `build/cpp` for the generated C++, a `project.fried` declaring the game's identity, an `assets/` for the game's own assets, a `sce_sys/` for a Vita build, a `switch/icon.jpg` for a Switch one, a `3ds/icon.png` for a 3DS one and, optionally, a `cg50/icon-uns.png` and `cg50/icon-sel.png` (92x64, the menu icon unselected and selected) for an fx-CG50 one. It then builds with the same commands the sandbox does.

## VS Code

Install the recommended extensions when prompted (C/C++, CMake Tools, Haxe & Neko). **Ctrl+Shift+B** runs the default build task, which regenerates the C++ from Haxe, configures CMake and builds; **F5** builds and launches under the debugger.

CMake Tools auto-configure on open is disabled on purpose, because configuring has to happen after the Haxe generation step. Use the build task, not the CMake Tools sidebar. The debug config uses `cppdbg`/`gdb`, matching the verified Linux/GCC setup.

IntelliSense follows the PC build, so the files only a console compiles, such as `native/graphics/renderer_citro.cpp`, show errors under it. For those, pick the **Nintendo 3DS** configuration (*C/C++: Select a Configuration*), which reads the flags from `build/3ds/compile_commands.json` and so needs that build tree configured first.

For the Flatpak build of VS Code, see [`docs/flatpak.md`](docs/flatpak.md).
