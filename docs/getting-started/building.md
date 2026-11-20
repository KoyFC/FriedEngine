# Building

To build a game, [Fried Project Manager](https://github.com/KoyFC/FriedProjectManager) is the recommended way: it runs these same steps from its build button for each platform it lists, with the toolchain that platform needs already chosen. What follows is the same build by hand, for the engine's own sandbox, and a game builds with the same commands from its own folder.

`sandbox/` is a small Haxe program that exercises the runtime, and it consumes the engine exactly the way a game does, so it is also the working example of a game's build. Every build starts the same way, by generating its C++ from Haxe, which is identical for every platform:

```sh
cd sandbox
haxe build.hxml
cd ..
```

The first PC configure on a machine downloads the sources of SDL2 and its companions, about 170 MB unpacked, and compiles them once into a cache shared by every build tree and project: `~/.cache/fried-engine/deps` on Linux (or under `$XDG_CACHE_HOME`) and `%LOCALAPPDATA%\fried-engine\deps` on Windows. That one needs an internet connection and takes a few minutes; later build trees with the same compiler and configuration link the installed libraries, and configure in about a second. A different compiler, a Debug build next to a Release one, or an edit to `cmake/pc_sdl2/CMakeLists.txt` compiles its own set the first time. `-DFRIED_DEPS_CACHE=<directory>` moves the cache, and `-DFRIED_DEPS_CACHE=` with nothing after it keeps everything inside each build tree instead. Deleting the cache is safe: the next configure builds it again.

## Linux

```sh
cmake -S . -B build
cmake --build build
./build/sandbox/fried_sandbox
```

## Windows, from Linux

```sh
cmake -S . -B build/windows -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/mingw-w64.cmake
cmake --build build/windows
wine build/windows/sandbox/fried_sandbox.exe
```

That produces `build/windows/sandbox/fried_sandbox.exe` with an `assets/` folder next to it, and the two are the whole game: the executable is linked statically, so it needs no DLL beyond the ones Windows itself ships. A Release build opens no console window, so its log is only visible from a Debug one (`-DCMAKE_BUILD_TYPE=Debug`) or under Wine, which prints it to the terminal either way.

## Windows, on Windows

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

## Other platforms

- [PlayStation Vita](../platforms/vita.md)
- [Nintendo Switch](../platforms/switch.md)
- [Nintendo 3DS](../platforms/3ds.md)
- [Nintendo DS](../platforms/nds.md)
- [Casio fx-CG50](../platforms/cg50.md)
- [Web](../platforms/web.md)
