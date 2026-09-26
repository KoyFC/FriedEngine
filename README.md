# Fried Engine

A game engine written primarily in [Haxe](https://haxe.org/), compiled to native C++ via [hxcpp](https://github.com/HaxeFoundation/hxcpp), on top of [SDL2](https://www.libsdl.org/) as the platform layer, with [CMake](https://cmake.org/) as the common build system across every target platform: Windows, Linux, macOS, and PlayStation Vita (via VitaSDK).

```
Haxe -> hxcpp -> generated C++ -> CMake -> toolchain/compiler -> executable
```

This repository contains **only the engine**. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for what is implemented and why.

## Project status

- [x] 1. Prove Haxe -> C++ -> CMake -> executable on PC (`sandbox/`)
- [x] 2. Integrate SDL2 (`sandbox/` opens and closes a real window)
- [x] 3. Minimal runtime (Application, Game Loop, Time, Window, Input, Events, Logging, Filesystem, Assets)
- [x] 4. Engine and game asset roots, read-only, verified at compile time
- [x] 5. Renderer and resources (`Renderer`, `Texture`, `Font`, `Sound`, `Music`)
- [x] 6. Port the runtime to PlayStation Vita (VitaSDK toolchain, `app0:` asset root)
- [x] 7. Define `project.fried`, and the writable user data path, which needs the game identity it declares
- [ ] 8. Fried Project Manager: create the basic structure of a new game project
- [ ] 9. Prove Fried Engine as a submodule in an external project
- [ ] 10. Real test game

## Requirements (PC)

- [Haxe](https://haxe.org/) 4.3+
- [hxcpp](https://lib.haxe.org/p/hxcpp/) (`haxelib install hxcpp`)
- CMake 3.20+
- A C++17 compiler: GCC, Clang or MSVC
- SDL2 2.0+, plus SDL2_image, SDL2_mixer and SDL2_ttf, each with its CMake package config available to `find_package(... CONFIG)` (e.g. the distro's `SDL2-devel` or `libsdl2-dev` family of packages)

## Requirements (PlayStation Vita)

- [VitaSDK](https://vitasdk.org/), with `$VITASDK` set and its `bin/` on `PATH`
- SDL2, SDL2_image, SDL2_mixer and SDL2_ttf from VitaSDK's package manager (`vdpm sdl2 sdl2_image sdl2_mixer sdl2_ttf`)
- Haxe, hxcpp and CMake as above: the Haxe side of the build is the same on every platform

## Building the sandbox

The sandbox is a small Haxe program that exercises the engine's runtime. It is compiled to C++ by hxcpp, and that generated C++ is compiled and linked entirely by CMake, not by hxcpp's own build tool.

1. Generate the C++ from Haxe:

   ```sh
   cd sandbox
   haxe build.hxml
   cd ..
   ```

2. Configure and build with CMake, from the repo root:

   ```sh
   cmake -S . -B build
   cmake --build build
   ```

   `sandbox/CMakeLists.txt` also stands on its own, exactly as a game's does, so it can be configured directly instead: `cmake -S sandbox -B sandbox/build`. The only difference is the build type, which the repo root defaults to Release and a directly configured project leaves to you, as it does for any game.

3. Run it:

   ```sh
   ./build/sandbox/fried_sandbox
   ```

A real SDL2 window opens, with the sandbox's own icon on it, and `fried.Application.run()` drives the game loop until the window is closed, drawing the sandbox's sprite in the middle of the window and a line of text above it, with its music looping. Space plays a sound, M pauses and resumes the music. The line of text starts with how many times the sandbox has been run, counted in a file it keeps in its own writable user data path. The sandbox logs its base path, that user data path, the assets it resolved from each asset root, and the window events it receives.

Verified working on Linux (GCC) with Haxe 4.3.7 and hxcpp 4.3.2. `cmake/Hxcpp.cmake`'s runtime source lists and compiler defines were derived from a real hxcpp build for that version; see the comment at the top of that file if you need to re-derive them.

## Building the sandbox for PlayStation Vita

The generated C++ is the same, so step 1 above is unchanged. Configure a second build tree with the toolchain file VitaSDK ships, which is what turns on every Vita branch in this repository's CMake:

```sh
cmake -S . -B build/vita -DCMAKE_TOOLCHAIN_FILE=$VITASDK/share/vita.toolchain.cmake
cmake --build build/vita
```

That produces `build/vita/sandbox/fried_sandbox.vpk`, with both asset roots under `app0:/assets/` and the LiveArea files from `sandbox/sce_sys/`. Copy it to the console and install it with VitaShell.

Keep spaces out of the path, both to the project and to its build tree. VitaSDK's packaging step passes every path to `vita-pack-vpk` unquoted, as bare `-a <source>=<destination>` pairs, so a space splits an argument and the packing fails after the C++ has already compiled and linked. It surfaces as CMake failing to copy `<target>.vpk.out`, which does not name the real cause. A PC build is unaffected.

Runs on real hardware. hxcpp has no Vita target of its own, so `cmake/Hxcpp.cmake` compiles its runtime against newlib with the gaps filled by `cmake/vita/newlib/`, and `sys.io.Process` and `sys.net.Socket` are left out of the build entirely.

## Using the engine in a game

The engine is consumed as a Git submodule of the game that uses it:

```sh
git submodule add https://github.com/KoyFC/FriedEngine.git engine
```

A game's `CMakeLists.txt` then needs two lines for the engine:

```cmake
cmake_minimum_required(VERSION 3.20)
project(MyGame LANGUAGES CXX)

include(${CMAKE_CURRENT_SOURCE_DIR}/engine/cmake/FriedEngine.cmake)

fried_add_game(my_game)
```

and its `build.hxml` points at the submodule's source:

```
-cp engine/src
-cp src
-main Main
-cpp build/cpp
-D no-compilation
```

`fried_add_game()` expects the layout those two files imply, relative to the project root: `build/cpp` for the generated C++, a `project.fried`, an `assets/` for the game's own assets, and a `sce_sys/` for a Vita build. Nothing else about the engine reaches the game's build files: the SDL2 packages, the engine's own C++ and both asset roots are the engine's to know.

A game then builds with the same commands the sandbox does, from the project root:

```sh
haxe build.hxml
cmake -S . -B build
cmake --build build
```

That produces `build/my_game` with both asset roots copied next to it, or `build/my_game.vpk` when the build tree is configured with the VitaSDK toolchain file. `sandbox/` consumes the engine exactly this way, so it is a working example of a game's build rather than a special case.

## Assets

Game code resolves assets through `fried.io.Assets`, which has one member per asset root:

```haxe
Assets.engine("font.ttf")    // an asset shipped by the engine
Assets.game("sprite.png")    // an asset shipped by the game
```

Both are macros: the path is checked at compile time, and `game()` is not available to engine code. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full design.

## Drawing

`fried.Application` owns the renderer; a `fried.Window` is only a window. Create one from the window, load what you draw through `fried.io.Assets`, and draw in the update callback:

```haxe
import fried.Application;
import fried.Window;
import fried.graphics.Font;
import fried.graphics.Renderer;
import fried.graphics.Texture;
import fried.io.Assets;

var window = new Window("Game", 640, 480);
var renderer = Application.createRenderer(window);
renderer.setDrawColor(24, 24, 32);

var sprite = Texture.load(renderer, Assets.game("sprite.png"));

var font = new Font(Assets.engine("font.ttf"), 16);
var label = font.renderText(renderer, "Score: 0", 220, 220, 230);

Application.run(function() {
    renderer.drawTexture(sprite, 100, 100);
    renderer.drawTexture(label, 16, 16);
});
```

A texture comes either from a file, through `Texture.load()`, or from a font, through `renderText()`, which is why neither is a constructor call: both produce the same drawable texture from a different source. Rendered text is a texture like any other, so build it when it changes rather than every frame, and `destroy()` it the same way.

The loop clears before the update and presents after it, so the callback only draws. Vsync is on by default and paces the loop at the display's refresh rate; `Application.targetFps` applies only when there is no vsync renderer.

The engine's types are split by domain (`fried`, `fried.input`, `fried.io`, `fried.graphics`, `fried.audio`), so a game that would rather not name them one by one can put an `import.hx` at the root of its own source directory and write no engine imports at all in the files below it:

```haxe
// src/import.hx
import fried.*;
import fried.audio.*;
import fried.graphics.*;
import fried.input.*;
import fried.io.*;
```

The file has to be the game's own: `import.hx` applies to the modules under the classpath it sits in, so the one the engine ships covers engine code only.

## Audio

Sounds and music are loaded the same way, through `fried.io.Assets`, and neither needs the renderer:

```haxe
import fried.audio.Music;
import fried.audio.Sound;
import fried.io.Assets;

var beep = new Sound(Assets.game("beep.wav"));
beep.volume = 0.6;
beep.play();

var theme = new Music(Assets.game("music.wav"));
Music.volume = 0.4;
theme.play();
```

`Sound` is for short effects, mixed on any free channel, so the same sound can overlap with itself. `Music` is the streamed one, and SDL_mixer streams one at a time: a second `play()` replaces the first, and `pause()`, `resume()` and `stop()` on a `Music` that is not the one playing do nothing. Volume is per sound but global for music, which is why `Music.volume` is static.

## The window icon

A window takes its icon from the game's own assets, like anything else it loads:

```haxe
var window = new Window("Game", 640, 480);
window.setIcon(Assets.game("icon.png"));
```

Anything SDL_image decodes works, at whatever size the image happens to be. The path goes through `fried.io.Assets`, so a missing file is a compile error rather than a window that quietly keeps the default icon, and a file that is not a decodable image throws at the call.

The Vita's `sce_sys/icon0.png` is a separate file for a separate job: the console's installer reads it out of the `.vpk`, and it has to be a palette PNG (see [`ARCHITECTURE.md`](ARCHITECTURE.md)). The console has nothing to show a window icon on, so `setIcon` has no effect there and a game can call it without branching on the platform.

## The project file

A game declares itself in a `project.fried` at its own root, next to its `build.hxml`. It is JSON, and the sandbox's is [`sandbox/project.fried`](sandbox/project.fried):

```json
{
	"name": "Fried Sandbox",
	"organization": "Fried Engine",
	"version": "01.00",
	"window": {
		"title": "Fried Engine sandbox"
	},
	"vita": {
		"titleId": "FRIE00001"
	}
}
```

`fried.Project` reads it at compile time, so what reaches the program is a constant and the file itself never ships with the game:

```haxe
import fried.Project;

var window = new Window(Project.windowTitle(), 640, 480);
```

`name` and `organization` are the identity the writable path below is built from, `version` and `vita.titleId` are what CMake hands to the Vita packaging step, and `window.title` is the window title. The file is looked up as `project.fried` relative to the directory `haxe` runs in, which is the project root; `-D fried-project=<path>` points somewhere else.

## Saves and user config

Nothing under the asset roots is writable, because nothing can be: the Vita mounts `app0:` read-only. Anything that has to survive a run goes through `fried.io.UserData` instead, whose root SDL resolves per platform from the identity in `project.fried` (`~/.local/share/<organization>/<name>/` on Linux, `%APPDATA%\<organization>\<name>\` on Windows, `ux0:/data/<organization>/<name>/` on the Vita):

```haxe
import fried.io.UserData;

if (UserData.exists("saves/slot1.json")) {
    var save = UserData.read("saves/slot1.json");
}

UserData.write("saves/slot1.json", '{"level": 3}');
```

Paths are relative to that root, and may not be absolute or contain `..`. `write()` creates the directories its path names, and `UserData.path` is the root itself, already created by SDL.

## VS Code

Install the recommended extensions when prompted (C/C++, CMake Tools, Haxe & Neko), then:

- **Ctrl+Shift+B** runs the default **Build sandbox** task: it regenerates C++ from Haxe, configures CMake, and builds.
- **F5** builds and launches `fried_sandbox` under the debugger.

CMake Tools auto-configure on open is disabled on purpose: the sandbox's `CMakeLists.txt` needs `sandbox/build/cpp/` to already exist, so configuring must happen after the Haxe generation step. Use the build task, not the CMake Tools sidebar.

The debug config uses `cppdbg`/`gdb`, matching this repository's verified Linux/GCC setup; it will need an `lldb`/`cppvsdbg` variant once Windows/macOS are supported.

If you use the Flatpak build of VS Code, see [`docs/flatpak.md`](docs/flatpak.md): the sandbox cannot reach the host toolchain, and the tasks forward the commands to the host for you.
