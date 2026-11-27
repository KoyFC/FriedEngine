# Third party notices

Fried Engine itself is under the MIT License, see [`LICENSE`](LICENSE). These are the components that are bundled with it or linked into every game built with it. Each licence below is the one the component's own sources or files state.

## stb_image, stb_image_write and stb_truetype

`native/third_party/stb_image.h` (v2.30), `native/third_party/stb_image_write.h` (v1.19, used only by the asset import tool) and `native/third_party/stb_truetype.h` (v1.26), by Sean Barrett and contributors, <https://github.com/nothings/stb>. Each header offers its terms as two alternatives at its end: the MIT License, or the public domain (Unlicense).

## cgltf

`native/third_party/cgltf.h` (v1.14), by Johannes Kuhlmann, <https://github.com/jkuhlmann/cgltf>, under the MIT License, which the header carries at its end. It reads glTF models in the asset import tool, and on PC in a game, where a model that has not been imported is converted as it is read.

## Nunito Sans

`assets/NunitoSans.ttf`, Copyright 2016 The Nunito Sans Project Authors (<https://github.com/Fonthausen/NunitoSans>), licensed under the SIL Open Font License, Version 1.1. The full text is in [`licenses/NunitoSans-OFL.txt`](licenses/NunitoSans-OFL.txt).

## SDL2, SDL2_image, SDL2_mixer and SDL2_ttf

SDL2 2.32.10, SDL2_image 2.8.12, SDL2_mixer 2.8.2 and SDL2_ttf 2.24.0, Copyright (C) 1997-2025 Sam Lantinga and contributors, <https://www.libsdl.org/>, under the zlib license that each `LICENSE.txt` carries. On PC they are downloaded as release tarballs and linked statically into every game. The versions are the ones `cmake/PcDependencies.cmake` and `cmake/pc_sdl2/CMakeLists.txt` pin.

Built the way the engine builds them, SDL2_image reads images through stb_image, and SDL2_mixer reads WAV, Ogg Vorbis through a modified stb_vorbis (v1.22, public domain or MIT) and MP3 through minimp3 (public domain, CC0).

## FreeType

Carried inside the SDL2_ttf 2.24.0 tarball and linked statically with it. FreeType is offered under the FreeType License (`FTL.TXT`) or the GNU General Public License version 2 (`GPLv2.TXT`), at <https://freetype.org/>.

## hxcpp

hxcpp 4.3.2, <https://github.com/HaxeFoundation/hxcpp>, whose runtime sources are compiled into every game. Its `LICENSE.txt` is a BSD style licence, Copyright (c) 2008 by the contributors, and refers to the individual source files for additional licence information.

## Console SDKs

A build for a console or the calculator also links libraries of its SDK, under the SDK's own licences: [devkitPro](https://devkitpro.org/) (libnds, libctru and the rest), [VitaSDK](https://vitasdk.org/) and [gint](https://git.planet-casio.com/Lephenixnoir/gint).
