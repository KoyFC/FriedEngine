# Nintendo Switch

## Building

```sh
cmake -S . -B build/switch -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/Switch.cmake
cmake --build build/switch
```

That produces `build/switch/sandbox/fried_sandbox.nro`, which runs from hbmenu once copied anywhere under `sdmc:/switch/`. The assets travel inside the `.nro` as a romfs, so it is the only file to copy. Nothing it logs is visible on the console, so the scene on screen is the whole report a run gives.
