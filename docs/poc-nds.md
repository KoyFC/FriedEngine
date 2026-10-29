# Nintendo DS proof of concept

This is a feasibility study for a Nintendo DS port, not the port itself. It lives on the `poc/nds` branch, and each phase below records what was built, what was measured and what went wrong.

All timings come from melonDS 1.1 (Flatpak, interpreter, JIT off). melonDS does not emulate the ARM9's caches and main RAM wait states exactly, so every number here is an emulator number and has to be confirmed on hardware before it is relied on.

## Phase 0: environment and engine survey

### Environment

| Check | Result |
|---|---|
| `DEVKITPRO`, `DEVKITARM` | OK, `/opt/devkitpro` and `/opt/devkitpro/devkitARM` |
| `arm-none-eabi-gcc` | OK, devkitARM GCC 16.1.0 |
| libnds | OK, `libnds/include/nds.h`, with calico |
| grit, ndstool, mmutil | OK, in `/opt/devkitpro/tools/bin` |
| Emulator | OK, melonDS 1.1 as Flatpak `net.kuribo64.melonDS`; none on `PATH` |
| Haxe | OK, Haxe 4.3.7 and hxcpp 4.3.2 |
| CMake toolchain | OK, `$DEVKITPRO/cmake/NDS.cmake`, which sets `NINTENDO_DS` and `ARM9` and provides `nds_create_rom()` |
| Smoke test | OK, devkitPro's `hello_world` builds into a 161 KB `.nds` and runs in melonDS |

### What a backend implements

The engine is Haxe in `src/fried/` over hand-written C++ in `native/`, bound through one `extern class` per file, with every native resource crossing as an integer handle. A platform answers the headers in `native/`: `application`, `events`, `window`, `input`, `mouse`, `touch`, `gamepad` and `filesystem` under `platform/`, `renderer`, `texture` and `font` under `graphics/` (with `display` shared), and `sound` and `music` under `audio/`. Where a whole implementation differs it is a sibling file, which is how the fx-CG50 has 13 `*_gint.cpp` files chosen by `cmake/FriedEngine.cmake`. A DS backend would be the same shape with `*_nds.cpp` files.

Assets are referenced by logical path through the `Assets.engine()` and `Assets.game()` macros, folded into a constant under `engine/` or `game/` at compile time. Only `native/platform/filesystem*.cpp` knows where that root physically is, so on the DS it would point into NitroFS.

### The fx-CG50 as the closest reference

The calculator is the one port without SDL2 and without an FPU. It keeps the same pipeline (hxcpp generates C++, CMake builds it) and patches copies of four hxcpp sources in `cmake/CG50.cmake`: Immix reserves 128 KB at a time instead of 1 MB, no GC helper threads, the thread info in a singleton, and aligned access to a string's hash. `cmake/gint/runtime.cpp` sizes the GC through `getenv` (384 KB working memory instead of 8 MB) and implements the atomics the SH4 lacks. Everything Haxe-side uses software floating point; only the rasterizer in `renderer_gint.cpp` uses 16.16 fixed point. The sandbox there is 1.6 MB of `.text` at `-Os`.

### Haxe standard library use

Safe on the DS: `String`, `Array`, `Map<Int|String, T>`, `Std.int`, `Std.downcast`, `Std.isOfType`, `haxe.ds.ArraySort`, `Math`. `Reflect` only appears in macros.

Needs work: `sys.io.File` and `sys.FileSystem` (`Filesystem`, `UserData`, `Log`) need NitroFS for reads and FAT through DLDI for `UserData` writes, which depends on the flashcart or emulator setup. `haxe.Json` and `Dynamic` in `UserData` are heavy but off the frame path. `Sys.time` and `Sys.sleep` go through `gettimeofday` and `nanosleep`.

### Floats in the critical path

Yes, throughout. `Transform`, `Camera`, `DrawQueue`, `Collider`, `Physics`, `InputAction`, `Time` and `Camera3D` are `Float`, which hxcpp compiles to `double`, and the native interface takes `float` and `double` (`fried_renderer_draw_texture`, `fried_renderer_fill_triangles` with `const double *`). Moving to fixed point would change the public API, so the proof of concept follows the fx-CG50: software floating point in Haxe, fixed point only inside the DS rasterizer.

## Phase 1: the runtime on its own

`poc/nds/hello/` is a Haxe program with no engine, built through the engine's own `cmake/Hxcpp.cmake` and devkitPro's `NDS.cmake`:

```
cd poc/nds/hello
haxe build.hxml
cmake -S . -B build/nds -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/NDS.cmake
cmake --build build/nds
```

It prints to the bottom screen through libnds's console and runs a few string, array, object, map, integer, float and GC tests, timed with `cpuGetTiming()`. Memory comes from newlib's `mallinfo()`, against the heap ceiling between `fake_heap_start` and `fake_heap_end`, and from hxcpp's `Gc.memInfo()`.

### What hxcpp needed

Everything compiled on the first try with the console defines the Vita, Switch and 3DS already use (`HX_LINUX`, `NEKO_LINUX`, `HXCPP_NO_DYNAMIC_LOADING`, `cmake/newlib/`, no sockets or processes). Two things failed after that, both already known from other ports:

1. **Atomics.** The link failed on `__atomic_compare_exchange_4`, `__atomic_fetch_add_4` and `__atomic_fetch_sub_4`. The ARM946E-S is ARMv5TE, which has no `ldrex`/`strex`, so GCC calls out for them, and devkitARM ships no libatomic. `cmake/nds/atomics.cpp` (now `cmake/nds/runtime.cpp`) implements them with interrupts masked through calico's `armIrqLockByPsr()`, which is what the fx-CG50 does for the SH4, made interrupt safe.
2. **Thread local storage.** The first run stopped at boot in `CriticalGCError` from `ExitGCFreeZone()`, reached through `hx/Tls.h`. newlib's `pthread_key_create()`, `pthread_setspecific()` and `pthread_getspecific()` are weak stubs returning `ENOSYS` here, which is exactly the 3DS failure. calico does provide native TLS (`ds9.ld` has a TLS region and the crash dump shows a thread pointer), so the 3DS's `cmake/libctru/hx_tls.h` override on `thread_local` fixes it unchanged.

`cmake/Hxcpp.cmake` adds `NINTENDO_DS` to the existing console branches and to those two fixes, and nothing else changes for other platforms.

The GC runs as hxcpp builds it by default, unlike on the fx-CG50: no `HXCPP_SINGLE_THREADED_APP`, default Immix block groups and default `getenv` sizes.

### Measurements

Built `MinSizeRel` (`-Oz`). The ROM is what `nds_create_rom()` writes, with calico's default ARM7 binary.

| | ARM | Thumb |
|---|---|---|
| ARM9 `.text` | 570,488 B | 410,540 B |
| `.data` + `.bss` | 34,596 B | 34,604 B |
| `.nds` | 688,128 B | 527,360 B |
| Heap ceiling (main RAM left for malloc) | 3,441 KB | 3,598 KB |

Memory, ARM build:

| Point | Heap in use | Heap peak | GC in use | GC current | GC reserved |
|---|---|---|---|---|---|
| Haxe `main()` entered | 1,098 KB | 1,101 KB | 0 KB | 31 KB | 984 KB |
| After the tests | 1,106 KB | 1,113 KB | 3 KB | 35 KB | 988 KB |
| After a major GC | 1,141 KB | 1,149 KB | 22 KB | 22 KB | 988 KB |

The resting cost of the runtime is therefore about 1.1 MB of heap, of which 984 KB is Immix's first reservation of 32 blocks of 32 KB. The test objects themselves are a few KB. The fx-CG50's patch to reserve 4 blocks at a time would bring that down to about 128 KB; that was not measured on the DS.

Timings, emulated:

| Test | ARM | Thumb |
|---|---|---|
| 200 `String +=` of `Std.string(i)` | 11,177 us | 10,665 us |
| 1000 `Array<Int>.push` | 902 us | 850 us |
| 200 objects with two `Float` and a `String` field | 8,779 us | 8,504 us |
| 100 `Map<String, Int>.set` | 4,064 us | 4,003 us |
| 10,000 integer multiply-adds | 4,645 us | 3,898 us |
| 10,000 `Float` multiply-adds | 38,959 us | 38,363 us |
| 1,000 `Math.sin` | 43,906 us | 44,042 us |
| Major GC, 22 KB live | 5,045 us | not run, see below |

A frame at 60 Hz is 16.7 ms. A `Float` multiply-add costs about 3.9 us, eight times an integer one, so a frame holds about 4,300 of them and nothing else. One `Math.sin` is 44 us. Allocation is not free either: 44 us per object with a string field, 56 us per string append.

### Problems

**The Thumb build loses live objects in a major GC.** Run as above, it ends in a data abort reading `numbers[999]`, whose array has a garbage data pointer (`0x7F5E`) once `Gc.run(true)` has run. Built with `-D skip_major_gc`, the same program prints every check correctly, and the ARM build passes the same collection. So the collector frees something still reachable when the code is Thumb. The working hypothesis is that hxcpp's conservative scan of the stack and registers, which goes through `setjmp` on ARM, misses a root in Thumb code; that has not been verified. Thumb is 28% smaller and no slower in melonDS, so it is worth fixing for a real port, but nothing below depends on it, and the ARM build is the one used from here on.

**Emulator output.** melonDS prints none of the no$gba debug port messages to its log, so results are read off the screen with a screenshot of the window (`spectacle -b -n -a -o <file>` on KDE).

### Decision point

The runtime fits and runs: the ARM9 load image is 0.57 MB of the 2.48 MB calico's `ds9.ld` allows, and the heap has 3.4 MB to give, 1.1 MB of which the GC takes before the game allocates anything. Nothing about hxcpp needed a new kind of fix, only the two already used on other ports.

The risk that the next phases have to measure is CPU, not memory: software `double` at roughly 3.9 us per operation, in an engine whose transforms, camera and draw queue are all `Float`. Phase 3 measures it on the real engine path.

## Phase 2: the sandbox on the DS

The proof of concept went on into a port, with the goal of running the sandbox. The drawing the fx-CG50 does on the CPU was first taken out of its gint files into `renderer_software.cpp`, `texture_software.cpp` and `font_software.cpp`, so the DS shares it instead of copying it; `ARCHITECTURE.md` describes how the DS platform sits on top of them.

The sandbox builds with `-DCMAKE_BUILD_TYPE=MinSizeRel` into 1,019,120 bytes of ARM9 `.text`, 22,316 of `.data` and 123,668 of `.bss`, the last being mostly the 96 KB frame, and a 1,888,256 byte `.nds` holding its 747 KB of assets in NitroFS. It boots, loads its PNG and the 569 KB TrueType font, which fits in memory here where it does not on the calculator, and draws its 2D scene and debug overlay on the top screen with the log on the bottom one. With nothing tuned yet, it runs at 12 frames a second in melonDS.

The first build seemed slower still: the overlay's frame counter crept, and what rotates turned at a fraction of its speed. calico's `gettimeofday()`, which `Sys.time()` reads, fills in only the RTC's whole seconds, so every frame but one a second had a delta of zero and that one was clamped to `Time`'s 0.25 s. `cmake/nds/runtime.cpp` now answers `gettimeofday()` from calico's system tick counter, which counts at about 524 kHz, anchored to the RTC's time on the first read. The counter does not run until `tickInit()` is called, which calico leaves until something schedules a task on it. The 12 frames a second were counted from the frame number over ten seconds of screenshots, not from the overlay alone.

### Drawing with the 3D engine

Timed with the system tick counter over 64 frames in melonDS, a frame of the CPU renderer took 83.5 ms at `-Oz` and 66.8 ms at `-O2`, and Haxe was 2 to 3 ms of it. Clearing the screen alone took 7 to 9 ms: main RAM takes writes slowly, and the ARM946E-S's data cache does not allocate on a write, so the renderer the calculator uses has little left to gain here. Another 9 to 11 ms went to waiting for the vertical blank, since every frame was longer than one.

The top screen is now drawn by the 3D engine instead (`ARCHITECTURE.md` describes how). Its first build ran at 30 frames a second: sending the sandbox's 318 glyphs a frame took 11.5 ms, 36 µs each, because their corners went through floats and `lround()`, all of it software floating point. In integers it takes 1.2 ms, and the sandbox runs at 60 frames a second. What remains of a frame is mostly laying out the text, about 6 ms in `font_software.cpp`, and the Haxe side of the draw queue, about 5 ms.

| | CPU renderer, `-Oz` | 3D engine |
|---|---|---|
| Frame | 83.5 ms | 14.5 ms of work, shown at 60 Hz |
| Clearing the screen | 8.8 ms | none |
| Rectangles (13) | 26.3 ms | 0.7 ms |
| Textures (3) | 15.5 ms | 0.3 ms |
| Text (20 lines) | 12.8 ms | 7.0 ms, 1.2 of it sending glyphs |
| Waiting for the vertical blank | 11.0 ms | 3.4 ms |

Laying out the text was mostly hash table lookups: `font_software.cpp` found each glyph's metrics, the kerning against the glyph before it and its place in the atlas in an `unordered_map`, every frame, and a lookup's modulo is a division the ARM9 has no instruction for. ASCII now sits in arrays, metrics and atlas places indexed by character and kerning by pair of printable characters, which took laying out the sandbox's text from 4.1 ms to 1.1 ms and finding the glyphs in the atlas from 1.5 ms to 0.7 ms.

On the Haxe side, the draw queue passed each texture's and each line of text's size to `Renderer.drawTextureRegion()` and `Renderer.drawText()` as optional arguments, which hxcpp boxes, so every one of those calls allocated; it now calls versions of them with none. It sorted its commands with `Array.sort()`, whose comparison is a function value hxcpp calls dynamically, and the sandbox's 48 commands took 1.1 ms; a merge sort with the comparison inlined, which only walks a queue already in order, takes 0.7 ms. What is left of a frame's work there is mostly double precision arithmetic, which Haxe's `Float` is and the ARM9 emulates: the camera's transform of every command, and the conversion of every coordinate to the single precision the native calls take.

With all of it, a frame of the sandbox's work is down from 14.5 ms to 9.7 ms, which leaves 7 ms of every 16.7 ms frame free.

Loading the 569 KB TrueType font from NitroFS takes 312 ms, and rasterizing its 95 printable ASCII glyphs into the atlas, the first time text is drawn, another 265 ms. The file stays in memory as long as the font is loaded.

### Pending: fonts converted at build time

Left for later, by decision. A font converted at build time, into its atlas, its metrics and a kerning table, would cut the boot by the half second above and free the 569 KB the TrueType file holds in RAM, 14 % of the DS's 4 MB. It would change nothing per frame, since glyphs are rasterized once already and the layout is what cost. On the fx-CG50 it would let the real font be drawn, where today the TrueType file does not fit in memory and the platform's pixel font is drawn instead. It would be the engine's first asset converted at build time, so it needs deciding first:

- **Sizes.** `Font.load()` takes the size at run time, so the sizes to convert would have to be declared, in `project.fried` for example, or one fixed size kept per font.
- **Characters.** ASCII alone, ASCII and Latin-1, or a set the project declares.
- **Platforms.** Only the DS and the fx-CG50, where the TrueType file is the problem, or every platform.

Images could be converted the same way, into the 3D engine's texel format, which would save decoding PNGs at load; with the sandbox's one 16x16 sprite there is nothing to measure yet.

melonDS needs DLDI enabled with an SD card image for the sandbox to start, since it writes user data before it opens a window and the DS has nowhere to write without a FAT volume.
