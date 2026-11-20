# Nintendo DS

## Building

```sh
cmake -S . -B build/nds -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/NDS.cmake -DCMAKE_BUILD_TYPE=Release
cmake --build build/nds
```

That produces `build/nds/sandbox/fried_sandbox.nds`, with its assets inside it in NitroFS, which runs from a flashcart or in melonDS. `Release` (`-O2`) is the build to use on the DS: its draw calls took 20 % less time in melonDS than with the native code at `-Oz`, for about 27 KB more code. `MinSizeRel` is safe on the DS only because `cmake/Hxcpp.cmake` builds the hxcpp code at `-O2` regardless: at `-Oz` GCC stops aligning string literals, hxcpp reads a header word in front of each one, and the ARM9 turns the unaligned load into garbage, so strings are taken for the wrong encoding and scene files fail to parse with `The scene file is version 0`. If that error ever appears on a DS build, check the optimization level of the hxcpp sources first. The scene draws on the top screen at 256x192 and the debug overlay moves to the bottom one, as on the 3DS; once the program ends, the bottom screen shows the end of the log, where an error that stopped it stays until a button is pressed. User data goes to `/data/<name>/` on a FAT volume, the flashcart's or the DSi's SD card, and the program stops without one: in melonDS, enable DLDI under Config, Emu settings, DLDI, with an SD card image, such as one made by `mkfs.fat -C -F 32 dldi.img 131072`. The top screen is drawn by the DS's 3D engine and the bottom one, when the game opens a second window there, on the CPU: the sandbox runs at 60 frames a second in melonDS with its debug overlay on the second.
