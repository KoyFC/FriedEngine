# Fried Engine

A game engine written primarily in [Haxe](https://haxe.org/), compiled to native C++ via [hxcpp](https://github.com/HaxeFoundation/hxcpp), on top of [SDL2](https://www.libsdl.org/) as the platform layer, with [CMake](https://cmake.org/) as the common build system across every target platform: Windows, Linux, macOS, and PlayStation Vita (via VitaSDK).

This repository contains **only the engine**. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for why, and for the full ecosystem architecture.

## Build pipeline

```
Haxe -> hxcpp -> generated C++ -> CMake -> toolchain/compiler -> executable
```

## Project status

- [x] 1. Prove Haxe -> C++ -> CMake -> executable on PC (`sandbox/`)
- [x] 2. Integrate SDL2 (`sandbox/` opens and closes a real window)
- [x] 3. Minimal runtime (Application, Game Loop, Time, Window, Input, Events, Logging, Filesystem, Assets)
- [ ] 4. Hybrid Filesystem and Asset Pipeline
- [ ] 5. Renderer and resources (Texture, Shader, Sound, Music, Font)
- [ ] 6. Real test game
- [ ] 7. Prove Fried Engine as a submodule in an external project
- [ ] 8. Define `project.fried`

## Assets

Assets live under the asset root that `fried.Filesystem` resolves (`assets/` next to the executable on PC, and whatever fixed mount point a console uses), split into two roots: `engine/`, shipped by the engine, and `game/`, shipped by the game. Each side keeps its own assets in a plain `assets/` folder in its own repository (`assets/` here, `sandbox/assets/` for the sandbox); the `engine/` and `game/` split only exists in the runtime layout CMake builds next to the executable:

```
assets/          in the engine repo   -->   assets/engine/   next to the executable
assets/          in the game repo     -->   assets/game/     next to the executable
```

The whole asset root is read-only on every platform, which is not a policy but a fact on the platforms this engine targets: Vita mounts the application at `app0:` and Switch mounts `romfs:` read-only. The asset API therefore has no write side at all. Anything that has to persist (saves, user config) belongs on a separate writable path and will get its own class, not yet written.

`fried.Assets` resolves a path in either root, and both of its members are macros:

```haxe
Assets.engine("font.ttf")    // -> <assetPath>engine/font.ttf
Assets.game("sprite.png")    // -> <assetPath>game/sprite.png
```

Being macros is what lets them do three things at compile time, so a bad asset reference is a build error at the call site rather than a failed load at runtime:

- **The asset has to exist.** The macro looks the path up in the source tree it belongs to and fails with `Asset not found: ../assets/nope.ttf` if it is not there.
- **`game()` is refused to engine code.** It reads the package of the class being compiled, and any caller under `fried` fails with `Game assets are not reachable from engine code.` Engine code has only `engine()`; game code has both, which is exactly the intended asymmetry, and it needs no separate class, classpath or runtime check to express.
- **The path cannot leave its root.** An absolute path, or one containing `..`, is rejected, so `Assets.engine("../game/sprite.png")` cannot be used to walk from one root into the other.

Both take a literal string, not a `String` expression: the argument is a macro constant, so a path built at runtime will not compile. That is deliberate at this stage, since it is what makes every asset reference verifiable; it can be loosened later without breaking any existing call.

Each call compiles down to a single `fried.Filesystem.getAssetPath("engine/font.ttf")`, the whole subpath already folded into one constant, so nothing about this costs anything at runtime.

The engine's own assets are found relative to `src/fried/Assets.hx` on the classpath, so a game gets that for free. The game's own assets are looked for in `assets/` relative to the directory `haxe` runs in, which is what `sandbox/build.hxml` relies on; `-D fried-game-assets=<dir>` overrides it for a project laid out differently.

## Build requirements (PC)

- [Haxe](https://haxe.org/) 4.3+
- [hxcpp](https://lib.haxe.org/p/hxcpp/) (`haxelib install hxcpp`)
- CMake 3.20+
- A C++17 compiler: GCC, Clang or MSVC
- SDL2 2.0+, plus SDL2_image, SDL2_mixer and SDL2_ttf, each with its CMake package config available to `find_package(... CONFIG)` (e.g. the distro's `SDL2-devel`/`SDL2_image-devel`/`SDL2_mixer-devel`/`SDL2_ttf-devel` or `libsdl2-dev`/`libsdl2-image-dev`/`libsdl2-mixer-dev`/`libsdl2-ttf-dev` packages)

## Building the sandbox

The sandbox proves a small Haxe program that is compiled to C++ by hxcpp, and that generated C++ is compiled and linked into an executable entirely by CMake, not by hxcpp's own build tool.

The repository's `.vscode/` tasks run this same pipeline from the editor. If you use the Flatpak build of VS Code, see [`docs/flatpak.md`](docs/flatpak.md): the sandbox cannot reach the host toolchain, and the tasks forward the commands to the host for you.

1. Generate the C++ from Haxe (from `sandbox/`):

   ```sh
   cd sandbox
   haxe build.hxml
   cd ..
   ```

   This runs `build.hxml` (`-cp ../src -cp src -main Main -cpp build/cpp -D no-compilation`), pulling in the engine's own Haxe source from `../src` alongside the sandbox's own `src`, and stops after generating `sandbox/build/cpp/` without invoking hxcpp's own compiler/linker.

2. Configure and build with CMake (from the repo root):

   ```sh
   cmake -S . -B build
   cmake --build build
   ```

   `cmake/Hxcpp.cmake` locates the `hxcpp` haxelib (via `haxelib path hxcpp`) and compiles `sandbox/build/cpp/` together with the hxcpp runtime sources, using the same defines hxcpp's own build tool would use.

3. Run it:

   ```sh
   ./build/sandbox/fried_sandbox
   ```

   Expected output:

   ```
   [0 | 0.0s] [SUCCESS] Fried Engine sandbox initialized. Base path: .../build/sandbox/
   [0 | 0.0s] [INFO] Read README.md: 8440 bytes
   [0 | 0.0s] [INFO] Asset path: .../build/sandbox/assets/
   [0 | 0.0s] [SUCCESS] Found asset: .../build/sandbox/assets/engine/font.ttf
   [0 | 0.0s] [SUCCESS] Found asset: .../build/sandbox/assets/game/sprite.png
   [0 | 0.0s] [SUCCESS] Found asset: .../build/sandbox/assets/game/beep.wav
   [0 | 0.0s] [SUCCESS] Window created: 640x480
   [1 | 0.75s] [INFO] Window focused
   [231 | 3.927s] [SUCCESS] Fried Engine sandbox run complete
   ```

   A real SDL2 window opens and `fried.Application.run()` drives the game loop (ticking `fried.Time`, pumping `fried.Events`, reporting clicks and window events) until the window is closed, then the window is destroyed and SDL shuts down. All of it goes through `fried.Application`/`fried.Window`/`fried.Events`/`fried.Time`/`fried.Input`/`fried.Filesystem`/`fried.Assets`/`fried.Log` (`src/fried/`), the engine's own Haxe code, not sandbox-only test code. The `Read README.md` line only appears when the sandbox is run from the repository root, since that path is relative to the working directory; the asset lines are resolved through the asset roots described below and work from anywhere.

Verified working on Linux (GCC) with Haxe 4.3.7 and hxcpp 4.3.2. `cmake/Hxcpp.cmake`'s runtime/std source lists and compiler defines were derived from a real hxcpp build for that version; see the comment at the top of that file if you need to re-derive them for a different hxcpp version.

## Building and debugging from VS Code

Install the recommended extensions when prompted (C/C++, CMake Tools, Haxe & Neko), then:

- **Ctrl+Shift+B** (or Terminal → Run Build Task) runs the default **Build sandbox** task: it regenerates C++ from Haxe, configures CMake, and builds.
- **F5** builds (via the task above) and launches `fried_sandbox` under the debugger (breakpoints work in `sandbox/src/Main.hx`'s generated C++ and in `cmake/Hxcpp.cmake`-built sources).

CMake Tools auto-configure on opening the folder is disabled on purpose (`cmake.configureOnOpen: false` in `.vscode/settings.json`): the sandbox's `CMakeLists.txt` requires `sandbox/build/cpp/` to already exist, so configuring must happen after the Haxe generation step, not before it. Use the build task instead of the CMake Tools sidebar for a clean build.

The debug launch config (`.vscode/launch.json`) uses `cppdbg`/`gdb`, which matches this repository's currently-verified Linux/GCC setup; it will need a `lldb`/`cppvsdbg` variant once Windows/macOS support is added.
