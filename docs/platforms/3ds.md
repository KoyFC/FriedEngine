# Nintendo 3DS

## Building

```sh
cmake -S . -B build/3ds -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/3DS.cmake
cmake --build build/3ds
```

That produces `build/3ds/sandbox/fried_sandbox.3dsx`, which runs from the Homebrew Launcher once copied anywhere under `sdmc:/3ds/`, with its assets inside it as on the Switch. The scene draws on the top screen at 400x240, and the debug overlay moves to the bottom one, which the sandbox opens as a second window wherever `Window.maxCount` allows one. Touching the bottom screen therefore shows up in the overlay and the log rather than in the world, which is on the other screen. Sound needs the console's DSP firmware dumped to `sdmc:/3ds/dspfirm.cdc` (by DSP1 on a console; any file of that name satisfies Azahar), and without it the program runs silent. In Azahar, use its OpenGL renderer: on Vulkan the right half of the top screen flashes black.
