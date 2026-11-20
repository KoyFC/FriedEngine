# Installing

What a build needs depends on the system it runs on and the platform it builds for. Find your system below and install everything its section lists, then the section for each console you want to build for, if any. Nothing else is needed: SDL2 and its companion libraries are downloaded and built by CMake itself for PC, so they are never installed by hand. Fedora is the Linux distribution everything here is verified on; the Debian, Ubuntu and Arch commands name the same software and are not verified.

## On Linux, for Linux

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

## On Linux, for Windows

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

## On Windows, for Windows

1. [Git for Windows](https://git-scm.com/download/win), with the installer's default options.
2. [Haxe](https://haxe.org/download/) 4.3 or later, from its Windows installer. It puts `haxe` and `haxelib` on `PATH` and sets up where haxelib keeps its libraries, so there is no `haxelib setup` to run.
3. The hxcpp library. Open a new terminal, PowerShell or `cmd`, so it sees the `PATH` the installer changed, and run:

   ```sh
   haxelib install hxcpp
   ```

4. A compiler, CMake and a build tool, in one of two ways. Building only through Fried Project Manager skips this step: without Visual Studio, it offers to download w64devkit for itself the first time it builds.
   - **Visual Studio**, the usual choice, and the one VS Code debugs with. Install [CMake](https://cmake.org/download/) 3.20 or later from its Windows installer, choosing to add it to `PATH`, then [Build Tools for Visual Studio](https://visualstudio.microsoft.com/visual-cpp-build-tools/) 2022 or later, ticking the **Desktop development with C++** workload, which brings the MSVC compiler and the Windows SDK. Visual Studio Community with the same workload works too.
   - **w64devkit**, a single download of under 100 MB with no installer, where Visual Studio takes several gigabytes. Download `w64devkit-x64-<version>.7z.exe` from its [releases](https://github.com/skeeto/w64devkit/releases) and run it: it unpacks a `w64devkit` folder into a location you choose, such as `C:\w64devkit`, and installs nothing else. It brings GCC, CMake, Ninja and gdb, so it replaces the CMake install as well. None of them is on the system `PATH`, so nothing outside that folder finds them on its own, VS Code included: every build has to be run from the terminal that `w64devkit.exe`, inside the folder, opens, which has them on its `PATH` for as long as it stays open.

## Consoles and the calculator

Each needs its SDK and SDL2 built for it, and these have only been verified from Linux. Install them after the section for your system above.

- **PlayStation Vita:** [VitaSDK](https://vitasdk.org/), following its install instructions, with `$VITASDK` set and its `bin/` on `PATH`. Then SDL2's companions from its package manager: `vdpm sdl2 sdl2_image sdl2_mixer sdl2_ttf`. The engine builds its own SDL2 for the Vita once, into `~/.cache/fried-engine/deps`, with a patch that lets the 3D draw inside SDL's GXM renderer (see the 3D section of `ARCHITECTURE.md`). The 3D compiles its shaders on the console with `libshacccg.suprx` in `ur0:data/`, where vitaGL games already require it, and without it meshes are drawn by the CPU. Extracting it is covered by these guides: <https://samilops2.gitbook.io/vita-troubleshooting-guide/shader-compiler/extract-libshacccg.suprx> and <https://cimmerian.gitbook.io/vita-troubleshooting-guide/shader-compiler/extract-libshacccg.suprx>. VitaSDK has no native Windows install of its own.
- **Nintendo Switch:** [devkitPro](https://devkitpro.org/wiki/Getting_Started), with `$DEVKITPRO` set, then `dkp-pacman -S switch-dev switch-pkg-config switch-sdl2 switch-sdl2_image switch-sdl2_mixer switch-sdl2_ttf`. `switch-pkg-config` is not optional: devkitPro's toolchain file refuses to configure without it, and it is how SDL2_image and SDL2_mixer are found, since devkitPro ships no CMake package config for either.
- **Nintendo 3DS:** the same devkitPro install with `dkp-pacman -S 3ds-dev`, and SDL2 and its companions built from [`packaging/3ds/`](https://github.com/KoyFC/FriedEngine/tree/main/packaging/3ds), since devkitPro ships no SDL2 for the 3DS.
- **Nintendo DS:** the same devkitPro install with `dkp-pacman -S nds-dev`. No SDL2 is involved: libnds is the whole platform there.
- **Casio fx-CG50:** the [fxSDK](https://git.planet-casio.com/Lephenixnoir/fxsdk) with gint, its `sh-elf-gcc` and its libstdc++, and that libstdc++ rebuilt with exceptions by [`packaging/cg50/`](https://github.com/KoyFC/FriedEngine/tree/main/packaging/cg50), since the fxSDK builds it without them. No SDL2 is involved: gint is the whole platform there.

- **Web:** the [Emscripten SDK](https://emscripten.org/docs/getting_started/downloads.html), activated in the shell (`source emsdk_env.sh`), and Python 3 to serve the result locally. SDL2 and its companions are Emscripten ports that emcc fetches itself.

## Using installed SDL2 on PC

A PC build can link SDL2, SDL2_image, SDL2_mixer and SDL2_ttf already installed on the system instead of building its own, if each comes with its CMake package config: configure with `-DFRIED_SYSTEM_SDL2=ON`. Nothing needs this, and the default is the one every machine builds the same way.
