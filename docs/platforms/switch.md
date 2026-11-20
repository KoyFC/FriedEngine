# Nintendo Switch

## Requirements

- devkitPro, installed as described in [Installing](../getting-started/installing.md#devkitpro), with `dkp-pacman -S switch-dev switch-pkg-config switch-sdl2 switch-sdl2_image switch-sdl2_mixer switch-sdl2_ttf`.
- `switch-pkg-config` is not optional: devkitPro's toolchain file refuses to configure without it, and it is how SDL2_image and SDL2_mixer are found, since devkitPro ships no CMake package config for either.

## Building

```sh
cmake -S . -B build/switch -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/Switch.cmake
cmake --build build/switch
```

### Output

That produces `build/switch/sandbox/fried_sandbox.nro`, which runs from hbmenu once copied anywhere under `sdmc:/switch/`. The assets travel inside the `.nro` as a romfs, so it is the only file to copy.

### Notes

- Nothing it logs is visible on the console, so the scene on screen is the whole report a run gives.

## How the port works

A Switch build is a third CMake build tree, configured with devkitPro's toolchain file. That toolchain sets `NINTENDO_SWITCH` and defines `__SWITCH__`, so the Switch keys off the console's own flags exactly as the Vita keys off `VITA` and `__vita__`. It also brings `nx_generate_nacp()` and `nx_create_nro()` with it, so `cmake/Switch.cmake` includes no SDK file, where `cmake/Vita.cmake` has to include VitaSDK's. Reaching the Switch through a hand-written devkitPro Makefile is the usual route; the toolchain file is what lets Fried keep one build system instead.

hxcpp cost the Switch almost nothing the Vita had not already paid, because both consoles run on newlib. `HX_LINUX`, `NEKO_LINUX`, `HXCPP_NO_DYNAMIC_LOADING`, the `__SNC__` on `Date.cpp` and the whole of `cmake/newlib/` are shared by the two, which is why that directory is named after the C library and not after either console. The one gap that is worse on devkitA64 is `readlink()`: VitaSDK declares it and links nothing, while devkitA64 does not declare it at all, so the shim has to declare it as well as answer it. `sys.io.Process` and `sys.net.Socket` are left out here too, the first because the console has no subprocesses and the second because libnx's sockets stay shut until a `socketInitializeDefault()` the engine never calls.

Two things diverged in `native/`. The asset root is `romfs:/assets/`, and unlike the Vita's `app0:` that mount is not automatic, so `fried_filesystem_init()` calls `romfsInit()` and a new `fried_filesystem_shutdown()` answers it, paired from `Application.shutdown()` the way the init already was from `Application.init()`. The writable path had to be branched as well, which the Vita did not need: devkitPro builds SDL on its dummy filesystem backend, so `SDL_GetPrefPath()` answers nothing and `fried.io.UserData` would throw at startup. It resolves to `sdmc:/switch/<name>/`, the flat list of one directory per homebrew application the console already keeps, which is why the organization is dropped rather than nested there.

Everything else compiles unchanged, and more of it than on the Vita. devkitPro's SDL2 drives the applet lifecycle, the controllers and the audio renderer itself, so the exit the HOME button asks for arrives as an ordinary `SDL_QUIT`, a joycon arrives as an ordinary `SDL_GameController`, and the mixer needs only the 48 kHz the console mixes at natively. Naming buttons by position is what makes the Nintendo face layout a non-event: a game asking for `South` gets B without knowing it.

Packaging is simpler than the Vita's in two ways and stricter in one. A `.nro` carries its metadata in a NACP built from fields `project.fried` already declared, so no key was added for it, and `elf2nro` receives quoted arguments, so the spaces in a path that break a Vita package are harmless here. The strict part is the icon: a 256x256 JPEG at `switch/icon.jpg`, a third format after the game's truecolor PNG and the Vita's palette PNG, and a project without one gets libnx's generic icon rather than a failure. The assets are staged into a romfs tree under the same `assets/` prefix the other two platforms use, and the `.nro` depends on the staged files rather than on the directory holding them, because `elf2nro` is handed a folder and would otherwise never notice an edited asset.

A window gets the size it asks for and the console stretches it to the whole screen, so the sandbox's 640x480 fills a 16:9 display distorted. There is no keyboard or mouse; the touchscreen is touch device 0. Nothing prints either: a `.nro` launched from hbmenu has nowhere to send stdout, so what is on screen is the whole report a run gives. When that report is a black screen, the first thing to rule out is the heap, which is smaller for homebrew launched from the album than for homebrew launched over a game.
