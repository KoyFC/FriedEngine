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
