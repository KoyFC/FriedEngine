# PlayStation Vita

## Requirements

- [VitaSDK](https://vitasdk.org/), following its install instructions, with `$VITASDK` set and its `bin/` on `PATH`. VitaSDK has no native Windows install of its own.
- SDL2's companions from its package manager: `vdpm sdl2 sdl2_image sdl2_mixer sdl2_ttf`.
- The engine builds its own SDL2 for the Vita once, into `~/.cache/fried-engine/deps`, with a patch that lets the 3D draw inside SDL's GXM renderer (see [3D](../architecture/3d.md)).
- The 3D compiles its shaders on the console with `libshacccg.suprx` in `ur0:data/`, where vitaGL games already require it, and without it meshes are drawn by the CPU. Extracting it is covered by these guides: <https://samilops2.gitbook.io/vita-troubleshooting-guide/shader-compiler/extract-libshacccg.suprx> and <https://cimmerian.gitbook.io/vita-troubleshooting-guide/shader-compiler/extract-libshacccg.suprx>.

## Building

```sh
cmake -S . -B build/vita -DCMAKE_TOOLCHAIN_FILE=$VITASDK/share/vita.toolchain.cmake
cmake --build build/vita
```

### Output

That produces `build/vita/sandbox/fried_sandbox.vpk`, which can be installed using VitaShell.

### Notes

- Keep spaces out of both the project path and the build tree path: VitaSDK's packaging step passes them to `vita-pack-vpk` unquoted, and the failure surfaces as CMake failing to copy `<target>.vpk.out`.

## How the port works

A Vita build is a second CMake build tree configured with VitaSDK's toolchain file. That toolchain sets `VITA` and every Vita branch keys off it, so there is no platform flag of our own and no second entry point: the same `CMakeLists.txt` files build every platform.

The engine's own C++ needed exactly one branch, in `native/platform/filesystem.cpp`, for the fixed read-only mount point. Everything else in `native/` compiles unchanged, because VitaSDK ships SDL2 and its three companion libraries: the window, the event loop, the renderer, the textures, the fonts and the audio are the same calls there as on PC. The writable path needed no branch either, since VitaSDK's SDL2 implements `SDL_GetPrefPath()`.

What the port actually cost is in `cmake/Hxcpp.cmake`. hxcpp has no Vita target and its runtime is written against glibc, so `HX_LINUX` and `NEKO_LINUX` select its generic POSIX paths, `HXCPP_NO_DYNAMIC_LOADING` compiles out a `dlopen()` layer a console has no use for, and `cmake/newlib/` fills the three remaining gaps: headers newlib does not ship, POSIX its headers hide from hxcpp, and `readlink()`, which newlib declares and VitaSDK does not implement. `sys.io.Process` and `sys.net.Socket` are left out of the build, since the Vita has no subprocesses and its sockets are a Sony API rather than the BSD one hxcpp calls. Haxe code using either fails to link rather than failing on the console.

Two packaging details are easy to lose hours to. The LiveArea files in `sce_sys/` must be palette PNGs: the installer rejects a truecolor one at the end of an otherwise valid install. And `sce_sys/icon0.png` is the installer's icon, read out of the package, which makes it a different thing from the window icon a game sets at runtime. A `sce_sys/pic0.png` (960x544, also a palette PNG) is packed when the project has one and skipped when it does not, since it is only the splash shown while the game boots.

The Vita has no keyboard or mouse, so those report nothing there; its buttons and sticks arrive as an ordinary `SDL_GameController`. Its two touch surfaces are two SDL touch devices, registered front first, so device 0 is the screen and device 1 the rear pad. SDL reports both against the one window, and the rear pad's position is scaled over that window just as the screen's is, so a game reads both in the same pixels and tells them apart only by the device.
