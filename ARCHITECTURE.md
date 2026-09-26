# Fried Engine Architecture

This document describes the decisions behind what is currently implemented, and why each one was made. It is not an API reference: the API is `src/fried/`. See `README.md` for the roadmap.

## Build pipeline

```
Haxe  --(hxcpp)-->  generated C++  --(CMake)-->  compiler  -->  executable
```

Haxe compiles to C++ with `-D no-compilation`, which stops hxcpp before its own build tool would run, and CMake compiles and links everything from there. `cmake/Hxcpp.cmake` locates the `hxcpp` haxelib and compiles its runtime sources alongside the generated code, so nothing depends on hxcpp's `Build.xml` or on `haxelib run hxcpp`.

The reason for taking that over is that CMake is then the single build system for every target platform, including the ones hxcpp has no support for. The Vita port is what proved it: the Haxe side did not change at all.

## Consuming the engine

A game includes one file and calls one function, `fried_add_game()`. `cmake/FriedEngine.cmake` resolves every path from its own location rather than from `CMAKE_SOURCE_DIR`, and that is the whole reason the engine works as a submodule: nothing in it requires the engine to be the top-level project.

`sandbox/CMakeLists.txt` is those same two lines with a different path to `cmake/`, so the sandbox takes the path an external game takes instead of a private one, and a change that would break a game breaks the sandbox first.

A consumer therefore never repeats the list of `native/*.cpp`, the four SDL2 packages, where the hxcpp haxelib lives, the VitaSDK link fixups, or the location of either asset root. It still writes `cmake_minimum_required`, `project()` and its own build-type defaults, because those are the consumer's policy rather than the engine's.

`fried::engine` is the engine's C++ as a static library. It can be one because `native/` includes nothing but SDL2 and the standard library, not a single hxcpp header, so it needs none of the defines the generated code is compiled with and it builds once per build tree instead of once per game. `native/` is its `PUBLIC` include root, which is what the `@:include` of every extern resolves against, and the SDL2 targets are `PUBLIC` links, so both reach the game's executable as usage requirements.

`fried_add_game()` takes a target name and nothing else. The paths it needs are the layout every Fried project has, relative to the caller: `build/cpp`, `project.fried`, `assets/`, and `sce_sys/` for the Vita. There are no keyword overrides, because nothing has needed to diverge from that layout.

The Haxe side needed no equivalent, since it never had a location to configure. A game's `build.hxml` adds `-cp <submodule>/src`, and the engine's own `assets/` is found relative to `src/fried/io/Assets.hx` on the classpath.

Because that layout is fixed and small, it can be generated: [Fried Project Manager](https://github.com/KoyFC/FriedProjectManager) lives in its own repository and writes a project already pinned to the engine. Nothing here knows about the tool, and the layout stays the contract between them.

## SDL2 and the native layer

SDL2 and its three companion libraries (SDL2_image, SDL2_mixer, SDL2_ttf) are found through CMake's own package configs and initialized together in `native/platform/application.cpp`, so failing to bring one up fails `fried.Application.init()` rather than surfacing later at the first load.

`native/` is hand-written C++ glue wrapping only the SDL2 calls the engine actually makes, bound to Haxe through a small `extern class` per file. No SDL pointer type crosses into Haxe: windows, renderers and textures are tracked by integer handle (`native/handle_pool.h`). Game code never sees SDL2, only the `fried.*` types.

Two things reach Haxe as events rather than as state because SDL only reports them that way: the mouse wheel, accumulated per frame in `native/platform/mouse.cpp`, and gamepad connection, handled in `native/platform/gamepad.cpp`. Window events are translated into a small queue that Haxe drains after SDL polling is over, so a game callback never runs while SDL state is mid-update.

## Ownership in the runtime

`fried.Application` owns the SDL lifecycle, the renderer and the game loop. `fried.Window` is only a window: it has no renderer field and nothing in it knows that renderers exist. A renderer is built from a window and owned by the application, so the two are created and destroyed separately, and only one renderer exists at a time.

The loop clears before the update callback and presents after it, so drawing code is only ever the middle of a frame that is already framed for it. A renderer is optional; with none, the loop runs exactly as it did before that step existed.

`vsync` is read back from SDL after creation rather than remembered from what was asked for, because a driver may refuse it and a loop that skipped its fps cap believing it had vsync would run unbounded. While vsync is active `targetFps` is ignored entirely: sleeping on top of vsync would push the next frame past the following vblank and halve the rate.

Input follows Unity's naming (`isKeyPressed` for held, `isKeyDown` for the frame it went down) rather than the more common convention where `IsKeyDown` means held. All three states come from comparing SDL's live state against a previous-frame snapshot the loop refreshes once per frame.

Gamepad buttons are named by position, not by label: the face buttons are `South`/`East`/`West`/`North`, so the same game code means A on an Xbox pad and cross on a PlayStation pad or a Vita. The triggers appear as both an axis and a button, because SDL reports them only as axes and a game wants them either way.

## Asset roots

Assets sit under one root, split in two at runtime: `engine/`, shipped by the engine, and `game/`, shipped by the game. Engine code may read only the engine root; game code may read both.

The split exists only in the runtime layout. Each side keeps its assets in a plain `assets/` directory in its own repository, and CMake copies them into place next to the executable, so a game never writes the word `game` anywhere in its own tree. The copy is its own `ALL` target rather than a `POST_BUILD` command, since `POST_BUILD` only fires when the target relinks and an edited asset would then never reach the build tree.

`fried.io.Assets.engine()` and `game()` are macros, folded at compile time into a single constant path. That is what buys the three checks worth having:

- The file must exist in the source tree, so a typo is a compile error at the call site rather than a null load on a platform nobody tested.
- `game()` refuses any caller whose package starts with `fried`, which is the entire mechanism behind the engine/game asymmetry. There is no second class, second classpath or runtime path inspection.
- Absolute paths and `..` are rejected, so neither root can walk into the other.

Paths must be macro constants, which is what makes those checks possible on every asset reference in the program. It can be relaxed later by falling back to unverified runtime resolution, without invalidating a single existing call; the reverse would not be true.

The boundary is a guard rail, not a sandbox. `fried.io.Filesystem.getAssetPath()` is public and has to be, so engine code that wanted to could still build a `game/` path by hand. What the macro buys is that it cannot happen by accident, and that it is visible in review.

## Project file and user data

A game declares itself in a `project.fried` at its own root. It is JSON because the file is written and rewritten by programs as much as by people: `haxe.Json` parses it in macro context and CMake reads it with `string(JSON ... GET ...)`, so whatever generates one can use its own serializer.

Every field is read by something. `name` and `organization` are the identity handed verbatim to `SDL_GetPrefPath()`; the engine does not sanitize them, since a silent rewrite would move a game's save directory without its author knowing. `version` and `vita.titleId` go to the Vita packaging step, which is why the version uses the `XX.XX` shape a Vita package requires. `window.title` is the window title. Each side reads only the keys it consumes.

`fried.Project` exposes the identity as macros folded into constants, so the file is an input to the build rather than something the game ships and opens at runtime. A missing or malformed file is one fatal error, since it is one fact about the whole project; a missing field is an error per call site, so one compile reports all of them. Unknown keys are ignored, so a file declaring more than this version consumes still builds. CMake registers it in `CMAKE_CONFIGURE_DEPENDS`, so editing it cannot produce a package with stale values.

Nothing under the asset root is writable, and that is not a rule the engine chose: the Vita mounts `app0:` read-only and the Switch mounts `romfs:` read-only, so an asset API with a write side could not be implemented there anyway. Anything that has to survive a run goes through `fried.io.UserData`, whose root SDL resolves per platform from that identity. It throws rather than falling back to another directory if SDL cannot resolve one, because a game silently saving somewhere nobody asked for is worse than one that does not start.

## PlayStation Vita

A Vita build is a second CMake build tree configured with VitaSDK's toolchain file. That toolchain sets `VITA` and every Vita branch keys off it, so there is no platform flag of our own and no second entry point: the same `CMakeLists.txt` files build both platforms.

The engine's own C++ needed exactly one branch, in `native/platform/filesystem.cpp`, for the fixed read-only mount point. Everything else in `native/` compiles unchanged, because VitaSDK ships SDL2 and its three companion libraries: the window, the event loop, the renderer, the textures, the fonts and the audio are the same calls on both platforms. The writable path needed no branch either, since VitaSDK's SDL2 implements `SDL_GetPrefPath()`.

What the port actually cost is in `cmake/Hxcpp.cmake`. hxcpp has no Vita target and its runtime is written against glibc, so `HX_LINUX` and `NEKO_LINUX` select its generic POSIX paths, `HXCPP_NO_DYNAMIC_LOADING` compiles out a `dlopen()` layer a console has no use for, and `cmake/vita/newlib/` fills the three remaining gaps: headers newlib does not ship, POSIX its headers hide from hxcpp, and `readlink()`, which newlib declares and VitaSDK does not implement. `sys.io.Process` and `sys.net.Socket` are left out of the build, since the Vita has no subprocesses and its sockets are a Sony API rather than the BSD one hxcpp calls. Haxe code using either fails to link rather than failing on the console.

Two packaging details are easy to lose hours to. The LiveArea files in `sce_sys/` must be palette PNGs: the installer rejects a truecolor one at the end of an otherwise valid install. And `sce_sys/icon0.png` is the installer's icon, read out of the package, which makes it a different thing from the window icon a game sets at runtime.

The Vita has no keyboard or mouse, so those report nothing there; its buttons and sticks arrive as an ordinary `SDL_GameController`. Touch input is not addressed yet.

## Source layout

The two source trees are split by different domains, because they are read by different people asking different questions.

`native/` is split by where an implementation comes from: `platform/` for what the operating system and the hardware provide, `graphics/` for what draws, `audio/` for what plays. Whoever opens it is asking which SDL calls the engine makes and what a new platform would have to answer for.

`src/fried/` is split by concept, because whoever opens it is writing a game and thinks in `Renderer`, `Key` and `Assets`: `fried` itself for what drives a program and the window it drives, then `fried.input`, `fried.io`, `fried.graphics` and `fried.audio`. So `fried.input.Key` is glued by `native/platform/input.cpp`, and that is deliberate rather than an oversight: a keyboard is part of the platform layer and part of input, and each tree names it the way its own reader would look for it.

Neither tree has a platform axis, and above the glue there cannot be one, since the whole point of `native/` is that the Haxe side never learns which platform it is on. Below it, a header is the contract shared by every platform, because it is what the `@:include` of the extern names.
