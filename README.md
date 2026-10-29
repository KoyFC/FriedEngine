# Fried Engine

A game engine written primarily in [Haxe](https://haxe.org/), compiled to native C++ via [hxcpp](https://github.com/HaxeFoundation/hxcpp), on top of [SDL2](https://www.libsdl.org/) (or [gint](https://git.planet-casio.com/Lephenixnoir/gint) on the Casio fx-CG50 and [libnds](https://github.com/devkitPro/libnds) on the Nintendo DS), with [CMake](https://cmake.org/) as the common build system across every target platform.

```
Haxe -> hxcpp -> generated C++ -> CMake -> toolchain/compiler -> executable
```

PC (verified on Linux with GCC, and on Windows built with MSVC or MinGW-w64 on Windows, or with MinGW-w64 from Linux), PlayStation Vita, Nintendo Switch, Nintendo 3DS, the Casio fx-CG50 graphing calculator and the web browser are implemented. The Nintendo DS runs the sandbox on both screens, with its buttons as a gamepad, its touchscreen as the bottom window's, and no audio yet. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for how it is put together and why.

This repository is the engine alone, and it is not the starting point for a game. A game lives in its own repository, pins the engine as a Git submodule, and builds it as part of its own build. The recommended way to start one is [Fried Project Manager](https://github.com/KoyFC/FriedProjectManager), which writes a project that already has the engine as a submodule and builds and runs as it comes out. [Using the engine in a game](#using-the-engine-in-a-game) is the same layout by hand. Cloning this repository on its own is for working on the engine itself, and `sandbox/` is its test program rather than a template.

## Installing

What a build needs depends on the system it runs on and the platform it builds for. Find your system below and install everything its section lists, then the section for each console you want to build for, if any. Nothing else is needed: SDL2 and its companion libraries are downloaded and built by CMake itself for PC, so they are never installed by hand. Fedora is the Linux distribution everything here is verified on; the Debian, Ubuntu and Arch commands name the same software and are not verified.

### On Linux, for Linux

1. A C++ compiler, `make`, CMake 3.20 or later, Git, and the development headers SDL2 is built against: X11 and Wayland for the window, and PulseAudio for sound, which also covers a PipeWire system.

   ```sh
   # Fedora
   sudo dnf install gcc-c++ make cmake git libX11-devel libXext-devel wayland-devel libxkbcommon-devel pulseaudio-libs-devel
   # Debian and Ubuntu
   sudo apt install g++ make cmake git libx11-dev libxext-dev libwayland-dev libwayland-bin libxkbcommon-dev libpulse-dev
   # Arch
   sudo pacman -S gcc make cmake git libx11 libxext wayland libxkbcommon libpulse
   ```

   A display or audio system whose headers are missing is left out of SDL2 without an error, and the game then fails to open a window or plays nothing, so install all of them.

2. Haxe 4.3 or later. Fedora and Arch package it as `haxe` (`sudo dnf install haxe`, `sudo pacman -S haxe`). Elsewhere, or where the packaged one is older than 4.3 (`haxe --version`), take the Linux binaries from [haxe.org](https://haxe.org/download/).

3. The hxcpp library, through `haxelib`, which comes with Haxe. The first command is only needed once, to tell haxelib where to keep its libraries:

   ```sh
   haxelib setup ~/haxelib
   haxelib install hxcpp
   ```

### On Linux, for Windows

Everything in [On Linux, for Linux](#on-linux-for-linux), plus MinGW-w64, the GCC that builds Windows executables, and Wine, to run them without leaving Linux:

```sh
# Fedora
sudo dnf install mingw64-gcc-c++ wine
# Debian and Ubuntu
sudo apt install g++-mingw-w64-x86-64 wine
# Arch
sudo pacman -S mingw-w64-gcc wine
```

The engine's toolchain file finds MinGW-w64's libraries where all three distributions put them. If yours puts them elsewhere, pass their folder with `-DFRIED_MINGW_SYSROOT=<path>` when configuring.

### On Windows, for Windows

1. [Git for Windows](https://git-scm.com/download/win), with the installer's default options.
2. [Haxe](https://haxe.org/download/) 4.3 or later, from its Windows installer. It puts `haxe` and `haxelib` on `PATH` and sets up where haxelib keeps its libraries, so there is no `haxelib setup` to run.
3. The hxcpp library. Open a new terminal, PowerShell or `cmd`, so it sees the `PATH` the installer changed, and run:

   ```sh
   haxelib install hxcpp
   ```

4. A compiler, CMake and a build tool, in one of two ways. Building only through Fried Project Manager skips this step: without Visual Studio, it offers to download w64devkit for itself the first time it builds.
   - **Visual Studio**, the usual choice, and the one VS Code debugs with. Install [CMake](https://cmake.org/download/) 3.20 or later from its Windows installer, choosing to add it to `PATH`, then [Build Tools for Visual Studio](https://visualstudio.microsoft.com/visual-cpp-build-tools/) 2022 or later, ticking the **Desktop development with C++** workload, which brings the MSVC compiler and the Windows SDK. Visual Studio Community with the same workload works too.
   - **w64devkit**, a single download of under 100 MB with no installer, where Visual Studio takes several gigabytes. Download `w64devkit-x64-<version>.7z.exe` from its [releases](https://github.com/skeeto/w64devkit/releases) and run it: it unpacks a `w64devkit` folder into a location you choose, such as `C:\w64devkit`, and installs nothing else. It brings GCC, CMake, Ninja and gdb, so it replaces the CMake install as well. None of them is on the system `PATH`, so nothing outside that folder finds them on its own, VS Code included: every build has to be run from the terminal that `w64devkit.exe`, inside the folder, opens, which has them on its `PATH` for as long as it stays open.

### Consoles and the calculator

Each needs its SDK and SDL2 built for it, and these have only been verified from Linux. Install them after the section for your system above.

- **PlayStation Vita:** [VitaSDK](https://vitasdk.org/), following its install instructions, with `$VITASDK` set and its `bin/` on `PATH`. Then SDL2 and its companions from its package manager: `vdpm sdl2 sdl2_image sdl2_mixer sdl2_ttf`. VitaSDK has no native Windows install of its own.
- **Nintendo Switch:** [devkitPro](https://devkitpro.org/wiki/Getting_Started), with `$DEVKITPRO` set, then `dkp-pacman -S switch-dev switch-pkg-config switch-sdl2 switch-sdl2_image switch-sdl2_mixer switch-sdl2_ttf`. `switch-pkg-config` is not optional: devkitPro's toolchain file refuses to configure without it, and it is how SDL2_image and SDL2_mixer are found, since devkitPro ships no CMake package config for either.
- **Nintendo 3DS:** the same devkitPro install with `dkp-pacman -S 3ds-dev`, and SDL2 and its companions built from [`packaging/3ds/`](packaging/3ds/README.md), since devkitPro ships no SDL2 for the 3DS.
- **Nintendo DS:** the same devkitPro install with `dkp-pacman -S nds-dev`. No SDL2 is involved: libnds is the whole platform there.
- **Casio fx-CG50:** the [fxSDK](https://git.planet-casio.com/Lephenixnoir/fxsdk) with gint, its `sh-elf-gcc` and its libstdc++, and that libstdc++ rebuilt with exceptions by [`packaging/cg50/`](packaging/cg50/README.md), since the fxSDK builds it without them. No SDL2 is involved: gint is the whole platform there.

- **Web:** the [Emscripten SDK](https://emscripten.org/docs/getting_started/downloads.html), activated in the shell (`source emsdk_env.sh`), and Python 3 to serve the result locally. SDL2 and its companions are Emscripten ports that emcc fetches itself.

### Using installed SDL2 on PC

A PC build can link SDL2, SDL2_image, SDL2_mixer and SDL2_ttf already installed on the system instead of building its own, if each comes with its CMake package config: configure with `-DFRIED_SYSTEM_SDL2=ON`. Nothing needs this, and the default is the one every machine builds the same way.

## Building the sandbox

To build a game, [Fried Project Manager](https://github.com/KoyFC/FriedProjectManager) is the recommended way: it runs these same steps from its build button for each platform it lists, with the toolchain that platform needs already chosen. What follows is the same build by hand, for the engine's own sandbox, and a game builds with the same commands from its own folder.

`sandbox/` is a small Haxe program that exercises the runtime, and it consumes the engine exactly the way a game does, so it is also the working example of a game's build. Every build starts the same way, by generating its C++ from Haxe, which is identical for every platform:

```sh
cd sandbox
haxe build.hxml
cd ..
```

The first PC configure on a machine downloads the sources of SDL2 and its companions, about 170 MB unpacked, and compiles them once into a cache shared by every build tree and project: `~/.cache/fried-engine/deps` on Linux (or under `$XDG_CACHE_HOME`) and `%LOCALAPPDATA%\fried-engine\deps` on Windows. That one needs an internet connection and takes a few minutes; later build trees with the same compiler and configuration link the installed libraries, and configure in about a second. A different compiler, a Debug build next to a Release one, or an edit to `cmake/pc_sdl2/CMakeLists.txt` compiles its own set the first time. `-DFRIED_DEPS_CACHE=<directory>` moves the cache, and `-DFRIED_DEPS_CACHE=` with nothing after it keeps everything inside each build tree instead. Deleting the cache is safe: the next configure builds it again.

### Linux

```sh
cmake -S . -B build
cmake --build build
./build/sandbox/fried_sandbox
```

### Windows, from Linux

```sh
cmake -S . -B build/windows -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/mingw-w64.cmake
cmake --build build/windows
wine build/windows/sandbox/fried_sandbox.exe
```

That produces `build/windows/sandbox/fried_sandbox.exe` with an `assets/` folder next to it, and the two are the whole game: the executable is linked statically, so it needs no DLL beyond the ones Windows itself ships. A Release build opens no console window, so its log is only visible from a Debug one (`-DCMAKE_BUILD_TYPE=Debug`) or under Wine, which prints it to the terminal either way.

### Windows, on Windows

With Visual Studio, from a regular terminal, PowerShell or `cmd`:

```sh
cmake -S . -B build
cmake --build build --config Release
build/sandbox/Release/fried_sandbox.exe
```

CMake finds Visual Studio by itself, so there is no developer prompt to open first. Its generator builds every configuration into its own folder and takes the configuration at build time rather than at configure time, which is why the build passes `--config` and the executable lands under `Release/`. That folder and the `assets/` folder in it are the whole game: the C++ runtime is linked statically like SDL2, so it needs no Visual C++ redistributable. A Release build opens no console window, and `--config Debug` builds one that does, under `build/sandbox/Debug/`, for reading the log.

With w64devkit, from the terminal `w64devkit.exe` opens, not from PowerShell or `cmd`, where its compiler is not on `PATH`:

```sh
cmake -S . -B build -G Ninja -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++
cmake --build build
./build/sandbox/fried_sandbox.exe
```

Ninja builds one configuration per build tree, Release unless `-DCMAKE_BUILD_TYPE=Debug` says otherwise, so the executable lands directly in `build/sandbox/`. Naming the compilers keeps CMake from picking up Visual Studio's instead where both are installed.

### PlayStation Vita

```sh
cmake -S . -B build/vita -DCMAKE_TOOLCHAIN_FILE=$VITASDK/share/vita.toolchain.cmake
cmake --build build/vita
```

That produces `build/vita/sandbox/fried_sandbox.vpk`, which can be installed using VitaShell. Keep spaces out of both the project path and the build tree path: VitaSDK's packaging step passes them to `vita-pack-vpk` unquoted, and the failure surfaces as CMake failing to copy `<target>.vpk.out`.

### Nintendo Switch

```sh
cmake -S . -B build/switch -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/Switch.cmake
cmake --build build/switch
```

That produces `build/switch/sandbox/fried_sandbox.nro`, which runs from hbmenu once copied anywhere under `sdmc:/switch/`. The assets travel inside the `.nro` as a romfs, so it is the only file to copy. Nothing it logs is visible on the console, so the scene on screen is the whole report a run gives.

### Nintendo 3DS

```sh
cmake -S . -B build/3ds -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/3DS.cmake
cmake --build build/3ds
```

That produces `build/3ds/sandbox/fried_sandbox.3dsx`, which runs from the Homebrew Launcher once copied anywhere under `sdmc:/3ds/`, with its assets inside it as on the Switch. The scene draws on the top screen at 400x240, and the debug overlay moves to the bottom one, which the sandbox opens as a second window wherever `Window.maxCount` allows one. Touching the bottom screen therefore shows up in the overlay and the log rather than in the world, which is on the other screen. Sound needs the console's DSP firmware dumped to `sdmc:/3ds/dspfirm.cdc` (by DSP1 on a console; any file of that name satisfies Azahar), and without it the program runs silent. In Azahar, use its OpenGL renderer: on Vulkan the right half of the top screen flashes black.

### Nintendo DS

```sh
cmake -S . -B build/nds -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/NDS.cmake -DCMAKE_BUILD_TYPE=MinSizeRel
cmake --build build/nds
```

That produces `build/nds/sandbox/fried_sandbox.nds`, with its assets inside it in NitroFS, which runs from a flashcart or in melonDS. The scene draws on the top screen at 256x192 and the debug overlay moves to the bottom one, as on the 3DS; once the program ends, the bottom screen shows the end of the log, where an error that stopped it stays until a button is pressed. User data goes to `/data/<name>/` on a FAT volume, the flashcart's or the DSi's SD card, and the program stops without one: in melonDS, enable DLDI under Config, Emu settings, DLDI, with an SD card image, such as one made by `mkfs.fat -C -F 32 dldi.img 131072`. The top screen is drawn by the DS's 3D engine and the bottom one, when the game opens a second window there, on the CPU: the sandbox runs at 60 frames a second in melonDS with its debug overlay on the second.

### Casio fx-CG50

The fxSDK's toolchain file sits under its install prefix (`~/.local` by default):

```sh
cmake -S . -B build/cg50 -DCMAKE_TOOLCHAIN_FILE=$HOME/.local/lib/cmake/fxsdk/FXCG50.cmake
cmake --build build/cg50
```

That produces `build/cg50/sandbox/fried_sandbox.g3a` and, next to it, a `Fried Sandbox/` folder holding the assets. With the calculator connected over USB in its storage mode, both go at the root of its storage memory, and the add-in then appears in the main menu. The assets stay outside the `.g3a`, which holds at most 2 MB, and audio is left out of them, since the calculator cannot play it; the game still loads and plays its sounds, silently. The screen is 396x224 and the keypad is the keyboard: the digits, the arrows, EXE as Enter, EXIT as Escape, DEL as Backspace, F1 to F6, SHIFT and ALPHA are those keys, the twelve keys above the digits are the letters A to L that ALPHA types with them, and the point key is Space. MENU always leaves for the calculator's main menu, as it does in every add-in, and the game sees its window lose and regain focus around it. Text set in a font too large for the calculator's memory, as the sandbox's is, falls back to the calculator's own pixel font. Everything is drawn by the CPU, so the sandbox runs at around 43 frames a second with neither of its overlays, 25 with one of them and 19 with both, and writing user data pauses the game for a moment, since the calculator's storage is slow to write.

### Web

```sh
source ~/emsdk/emsdk_env.sh
emcmake cmake -S . -B build/web
cmake --build build/web
```

That produces `build/web/sandbox/fried_sandbox.html` with its `.js`, `.wasm` and `.data` (the assets) next to it. A browser will not load those from a `file://` address, so opening the page with a double click leaves it stuck on loading. Serve the folder over HTTP instead, with the Python that is already on most machines:

```sh
cd build/web/sandbox
python3 -m http.server 8000
```

Then open <http://localhost:8000/fried_sandbox.html>. After a rebuild, reload with Ctrl+Shift+R, or the browser keeps the old files. The page is the game's canvas on a black background, and the engine's log goes to the browser's console (F12), where a failure also shows up.

The page keeps the engine's loop as it is and hands control back to the browser once per frame, so it runs at the display's refresh rate and ignores `Application.targetFps`. User data lives in memory and is gone when the page closes.

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

CMake Tools auto-configure on open is disabled on purpose, because configuring has to happen after the Haxe generation step. Use the build task, not the CMake Tools sidebar.

There is one debug configuration per system, picked once from the Run and Debug view: **Debug sandbox (Linux)** launches under `gdb`, and **Debug sandbox (Windows)** under the Visual Studio debugger, building with Visual Studio as [Windows, on Windows](#windows-on-windows) does, in its Debug configuration. On Windows the build task builds Debug too, so it is the same build F5 launches.

IntelliSense follows the PC build of the system VS Code runs on, through the **Linux** or **Win32** configuration the C/C++ extension picks by name. Both read SDL2's headers from `build/_deps/`, where a configure copies them from the cache, so they need the sandbox configured once; Linux also looks in `/usr/include/SDL2` for a build with `FRIED_SYSTEM_SDL2=ON`. On Windows, hxcpp's headers come from the haxelib repository under `%HAXEPATH%`. Either way, the files only a console compiles, such as `native/graphics/renderer_citro.cpp`, show errors under it. For those, pick the **Nintendo 3DS** configuration (*C/C++: Select a Configuration*), which reads the flags from `build/3ds/compile_commands.json` and so needs that build tree configured first.

For the Flatpak build of VS Code, see [`docs/flatpak.md`](docs/flatpak.md).
