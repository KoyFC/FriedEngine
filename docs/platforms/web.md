# Web

## Building

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

## How the port works

A web build is configured with Emscripten's toolchain (`emcmake`), which sets `EMSCRIPTEN`; `cmake/FriedEngine.cmake` turns it into `FRIED_WEB` and `cmake/Web.cmake` holds what is the browser's alone. It needed little: the SDL2 backend compiles unchanged against Emscripten's SDL2 port and its three companions, which `-sUSE_SDL*` flags make emcc build on first use, so the PC dependency recipe is skipped.

The loop in `Application.run()` is a plain `while`, and a browser draws only between the callbacks it runs. Rather than invert the loop, the link uses Asyncify, and `fried_application_wait_for_host_frame()` awaits `requestAnimationFrame`. It answers 1 on the web, where it replaces the frame budget's sleep, and 0 elsewhere, so the Haxe side still never learns the platform. The cost is a larger and slower wasm.

hxcpp has an Emscripten toolchain file of its own that the CMake pipeline does not use, so `cmake/Hxcpp.cmake` supplies what it would: `EMSCRIPTEN` (emcc only defines `__EMSCRIPTEN__`), the Linux defines for the std sources, no sockets or processes, and no pthread library, since the build is single-threaded. The assets are embedded with `--preload-file` under the same `assets/engine` and `assets/game` the PC build uses, so `filesystem.cpp` needs no branch. User data goes to SDL's default path inside Emscripten's in-memory filesystem and is lost on reload; persisting it would take IDBFS.
