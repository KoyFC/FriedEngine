# Installing

## Supported systems

A build runs on Linux or on Windows. macOS is not supported, and there are no instructions for it here.

## What to install

What a build needs depends on the system it runs on and the platform it builds for.

| Building for | On | Install |
|---|---|---|
| Linux | Linux | [On Linux, for Linux](#on-linux-for-linux) |
| Windows | Linux | [On Linux, for Linux](#on-linux-for-linux), then [On Linux, for Windows](#on-linux-for-windows) |
| Windows | Windows | [On Windows, for Windows](#on-windows-for-windows) |
| A console, the calculator or the web | Linux | [On Linux, for Linux](#on-linux-for-linux), then the platform's page under [Platforms](../platforms/index.md) |

Find your system above and install everything its section lists, then the section for each console you want to build for, if any. Nothing else is needed: SDL2 and its companion libraries are downloaded and built by CMake itself for PC, so they are never installed by hand.

## On Linux, for Linux

1. **Build tools and headers.** A C++ compiler, `make`, CMake 3.20 or later, Git, and the development headers SDL2 is built against: X11 and Wayland for the window, and PulseAudio for sound, which also covers a PipeWire system.

    Fedora is the Linux distribution everything here is verified on; the Debian, Ubuntu and Arch commands name the same software and are not verified.

    === "Fedora"

        ```sh
        sudo dnf install gcc-c++ make cmake git libX11-devel libXext-devel wayland-devel libxkbcommon-devel pulseaudio-libs-devel
        ```

    === "Debian and Ubuntu"

        ```sh
        sudo apt install g++ make cmake git libx11-dev libxext-dev libwayland-dev libwayland-bin libxkbcommon-dev libpulse-dev
        ```

    === "Arch"

        ```sh
        sudo pacman -S gcc make cmake git libx11 libxext wayland libxkbcommon libpulse
        ```

    A display or audio system whose headers are missing is left out of SDL2 without an error, and the game then fails to open a window or plays nothing, so install all of them.

2. **Haxe.** Haxe 4.3 or later. Fedora and Arch package it as `haxe` (`sudo dnf install haxe`, `sudo pacman -S haxe`). Elsewhere, or where the packaged one is older than 4.3 (`haxe --version`), take the Linux binaries from [haxe.org](https://haxe.org/download/).

3. **hxcpp.** The hxcpp library, through `haxelib`, which comes with Haxe. The first command is only needed once, to tell haxelib where to keep its libraries:

    ```sh
    haxelib setup ~/haxelib
    haxelib install hxcpp
    ```

### Check

```sh
haxe --version
haxelib list
cmake --version
```

Haxe should report 4.3 or later and `haxelib list` should show hxcpp.

## On Linux, for Windows

Everything in [On Linux, for Linux](#on-linux-for-linux), plus MinGW-w64, the GCC that builds Windows executables, and Wine, to run them without leaving Linux:

=== "Fedora"

    ```sh
    sudo dnf install mingw64-gcc-c++ wine
    ```

=== "Debian and Ubuntu"

    ```sh
    sudo apt install g++-mingw-w64-x86-64 wine
    ```

=== "Arch"

    ```sh
    sudo pacman -S mingw-w64-gcc wine
    ```

The engine's toolchain file finds MinGW-w64's libraries where all three distributions put them. If yours puts them elsewhere, pass their folder with `-DFRIED_MINGW_SYSROOT=<path>` when configuring.

## On Windows, for Windows

1. **Git.** [Git for Windows](https://git-scm.com/download/win), with the installer's default options.
2. **Haxe.** [Haxe](https://haxe.org/download/) 4.3 or later, from its Windows installer. It puts `haxe` and `haxelib` on `PATH` and sets up where haxelib keeps its libraries, so there is no `haxelib setup` to run.
3. **hxcpp.** The hxcpp library. Open a new terminal, PowerShell or `cmd`, so it sees the `PATH` the installer changed, and run:

    ```sh
    haxelib install hxcpp
    ```

4. **Compiler and build tools.** A compiler, CMake and a build tool, in one of two ways. Building only through Fried Project Manager skips this step: without Visual Studio, it offers to download w64devkit for itself the first time it builds.

    === "Visual Studio"

        The usual choice, and the one VS Code debugs with.

        - Install [CMake](https://cmake.org/download/) 3.20 or later from its Windows installer, choosing to add it to `PATH`, then [Build Tools for Visual Studio](https://visualstudio.microsoft.com/visual-cpp-build-tools/) 2022 or later, ticking the **Desktop development with C++** workload, which brings the MSVC compiler and the Windows SDK.
        - Visual Studio Community with the same workload works too.

    === "w64devkit"

        A single download of under 100 MB with no installer, where Visual Studio takes several gigabytes.

        - Download `w64devkit-x64-<version>.7z.exe` from its [releases](https://github.com/skeeto/w64devkit/releases) and run it: it unpacks a `w64devkit` folder into a location you choose, such as `C:\w64devkit`, and installs nothing else.
        - It brings GCC, CMake, Ninja and gdb, so it replaces the CMake install as well.
        - None of them is on the system `PATH`, so nothing outside that folder finds them on its own, VS Code included: every build has to be run from the terminal that `w64devkit.exe`, inside the folder, opens, which has them on its `PATH` for as long as it stays open.

### Check

```sh
haxe --version
haxelib list
cmake --version
```

Haxe should report 4.3 or later and `haxelib list` should show hxcpp.

## Consoles and the calculator

Each needs its SDK and SDL2 built for it, and these have only been verified from Linux. Install them after the section for your system above.

| Platform | SDK | Requirements |
|---|---|---|
| PlayStation Vita | VitaSDK | [Vita](../platforms/vita.md#requirements) |
| Nintendo Switch | devkitPro | [Switch](../platforms/switch.md#requirements) |
| Nintendo 3DS | devkitPro | [3DS](../platforms/3ds.md#requirements) |
| Nintendo DS | devkitPro | [DS](../platforms/nds.md#requirements) |
| Casio fx-CG50 | fxSDK | [fx-CG50](../platforms/cg50.md#requirements) |
| Web | Emscripten | [Web](../platforms/web.md#requirements) |

### devkitPro

The Switch, the 3DS and the DS share one install of [devkitPro](https://devkitpro.org/wiki/Getting_Started), with `$DEVKITPRO` set. Each platform's page lists the `dkp-pacman` packages it adds.

## Using installed SDL2 on PC

A PC build can link SDL2, SDL2_image, SDL2_mixer and SDL2_ttf already installed on the system instead of building its own, if each comes with its CMake package config: configure with `-DFRIED_SYSTEM_SDL2=ON`. Nothing needs this, and the default is the one every machine builds the same way.
