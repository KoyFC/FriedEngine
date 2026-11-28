# Nintendo 3DS

## Requirements

- devkitPro, installed as described in [Installing](../getting-started/installing.md#devkitpro), with `dkp-pacman -S 3ds-dev`.
- Nothing else: devkitPro ships no SDL2 for the 3DS, so the first configure builds SDL2 and its three companions from source into `~/.cache/fried-engine/deps`, once, as it does for PC. `-DFRIED_SYSTEM_SDL2=ON` links the packages of [`packaging/3ds/`](https://github.com/KoyFC/FriedEngine/tree/main/packaging/3ds) installed into devkitPro instead.

## Building

```sh
cmake -S . -B build/3ds -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/3DS.cmake
cmake --build build/3ds
```

### Output

That produces `build/3ds/sandbox/fried_sandbox.3dsx`, which runs from the Homebrew Launcher once copied anywhere under `sdmc:/3ds/`, with its assets inside it as on the Switch.

### Running

- Sound needs the console's DSP firmware dumped to `sdmc:/3ds/dspfirm.cdc` (by DSP1 on a console; any file of that name satisfies Azahar), and without it the program runs silent.
- In Azahar, use its OpenGL renderer: on Vulkan the right half of the top screen flashes black.

### Notes

- The scene draws on the top screen at 400x240, and the debug overlay moves to the bottom one, which the sandbox opens as a second window wherever `Window.maxCount` allows one.
- Touching the bottom screen therefore shows up in the overlay and the log rather than in the world, which is on the other screen.

## How the port works

A 3DS build is configured with devkitPro's 3DS toolchain file, which sets `NINTENDO_3DS` and defines `__3DS__`, and brings `ctr_generate_smdh()` and `ctr_create_3dsx()` the way the Switch's brings its NACP and `.nro` steps. What it does not bring is SDL2: devkitPro ships only SDL 1.2 for the 3DS, so `cmake/PcDependencies.cmake` builds SDL2 and its three companion libraries from source with that toolchain, once, the way it does for PC and Android, and finds them through their CMake package configs. `packaging/3ds/` builds the same libraries as pacman packages for `FRIED_SYSTEM_SDL2=ON`.

hxcpp had one gap here that neither of the other consoles had, although the 3DS runs on newlib too. libctru implements no pthread keys: `pthread_key_create()` and the rest are newlib stubs that fail, and `pthread_getspecific()` reads back null, so the GC lost its per-thread context on the first allocation and stopped with a zone mismatch. hxcpp lets a build replace its TLS header through `HX_TLS_H_OVERRIDE`, and `cmake/libctru/hx_tls.h` puts the same macros on `thread_local`, which libctru does implement for every thread it creates. Everything else in `cmake/Hxcpp.cmake` is shared with the other two consoles, apart from PIE, which a `.3dsx` does not use: its loader relocates it from the word relocations the toolchain compiles with.

In `native/`, the asset root and its `romfsInit()` are the Switch's, and the writable path needed no branch, since SDL's 3DS port answers `SDL_GetPrefPath()` with `sdmc:/3ds/<name>/`. Three things are the 3DS's own. Each screen is an SDL display and a window fills the one it is on whatever size it asks for, so `fried_window_create()` places a window on the first screen without one: the first window opened is the top screen at 400x240 and the second the bottom one at 320x240. The touchscreen reports against the bottom screen's window, so a game that never opens a second window receives no touch. And `fried_application_init()` calls `osSetSpeedupEnable()`, because SDL2main would have asked for the New 3DS's clock and cache and hxcpp brings its own `main()` instead.

SDL's 3DS port has no GPU render driver, only a software one that ran the sandbox at under 20 FPS, so the renderer and textures are the one part of the engine with a second implementation: `renderer_citro.cpp` and `texture_citro.cpp` draw through citro2d next to the `_sdl` files every other platform compiles, behind the same `renderer.h` and `texture.h`, and `cmake/FriedEngine.cmake` picks the pair. SDL still owns the windows, the input, the audio and the decoding of images and text. Fonts are shared by both backends because they meet them at three functions: `fried_texture_create_blank()` and `fried_texture_write()` build a glyph atlas a region at a time, and `fried_renderer_draw_tinted()` draws its glyphs. Writing a region on the 3DS tiles only those texels and flushes only the rows of tiles they fall in.

citro2d draws a whole frame, both screens, out of one vertex buffer sized when it starts and only emptied when the frame ends, and whatever does not fit is silently not drawn. The default held 16384 vertices, about 5400 triangles, so the 3D stress test at 1024 cubes, some 6000 triangles, filled it from the top screen and left the bottom one with nothing for its overlay. The buffer is now the largest citro2d can index, 65536 vertices, and triangles may use only half of it in a frame, so the triangles past that are the ones dropped while sprites, text and the other screen keep the other half.

The citro2d side is shaped by what the GPU wants. A texture's sides are powers of two between 8 and 1024 and its texels are laid out in 8x8 tiles, so a surface is converted and copied into tiles on upload, and the texture keeps the image's own size for `Texture.width` and `height`. A larger image is halved until it fits rather than refused, since on a 400x240 screen it is drawn scaled down anyway, and `Texture` logs a warning saying so, as does configuring any build for a project that lists `3ds` in `platforms`, or a 3DS build with no list, for each PNG asset over the limit, before anything runs; a region of it is still given in the image's own pixels. The screens need BGR8 rather than the RGBA8 SDL leaves them at, which `fried_renderer_create()` sets. A screen with no renderer is blanked, because the GPU never draws there and it would otherwise keep whatever the Homebrew Launcher left on it. One GPU frame holds every screen: the first draw of a frame opens it, each renderer's draws switch to its screen, and the first `fried_renderer_present()` ends it for both, waiting for the VBlank, so a renderer always reports vsync there.

The project's `display` applies to the top screen only, while the bottom one always draws at its own 320x240. citro2d has no viewport of its own, so the layout goes in its model matrix, translated to the viewport and scaled, whenever a renderer's scene begins. The bars are black rectangles painted over the whole frame just before it ends, rather than a scissor, which also hides whatever was drawn past the viewport.

Audio goes through the DSP, whose firmware is not something a homebrew application can carry: libctru loads it from `sdmc:/3ds/dspfirm.cdc`, dumped from the console. Without it no audio device opens, which is not fatal on any platform: `Application.init()` logs a warning and opens SDL's dummy audio driver instead, so sounds and music still load and play, unheard, and a game needs no branch for a console that cannot make sound.

The `.3dsx` packaging follows the Switch's. Its SMDH is built from `name`, `organization` and `version` in `project.fried`, the version going on the description line, and the icon is a 48x48 PNG at `3ds/icon.png`, with libctru's generic one in its place when a project has none. The romfs is staged by the same `cmake/DevkitProRomfs.cmake` the Switch uses, which is why that helper is named after devkitPro rather than either console.
