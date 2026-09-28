# Fried Engine Architecture

This document describes the decisions behind what is currently implemented, and why each one was made. It is not an API reference: the API is `src/fried/`. See `README.md` for the roadmap.

## Build pipeline

```
Haxe  --(hxcpp)-->  generated C++  --(CMake)-->  compiler  -->  executable
```

Haxe compiles to C++ with `-D no-compilation`, which stops hxcpp before its own build tool would run, and CMake compiles and links everything from there. `cmake/Hxcpp.cmake` locates the `hxcpp` haxelib and compiles its runtime sources alongside the generated code, so nothing depends on hxcpp's `Build.xml` or on `haxelib run hxcpp`.

The reason for taking that over is that CMake is then the single build system for every target platform, including the ones hxcpp has no support for. The Vita port is what proved it and the Switch is what confirmed it: the Haxe side did not change for either.

## Consuming the engine

A game includes one file and calls one function, `fried_add_game()`. `cmake/FriedEngine.cmake` resolves every path from its own location rather than from `CMAKE_SOURCE_DIR`, and that is the whole reason the engine works as a submodule: nothing in it requires the engine to be the top-level project.

`sandbox/CMakeLists.txt` is those same two lines with a different path to `cmake/`, so the sandbox takes the path an external game takes instead of a private one, and a change that would break a game breaks the sandbox first.

A consumer therefore never repeats the list of `native/*.cpp`, the four SDL2 packages, where the hxcpp haxelib lives, the link fixups each console needs, or the location of either asset root. It still writes `cmake_minimum_required`, `project()` and its own build-type defaults, because those are the consumer's policy rather than the engine's.

`fried::engine` is the engine's C++ as a static library. It can be one because `native/` includes nothing but SDL2 and the standard library, not a single hxcpp header, so it needs none of the defines the generated code is compiled with and it builds once per build tree instead of once per game. `native/` is its `PUBLIC` include root, which is what the `@:include` of every extern resolves against, and the SDL2 targets are `PUBLIC` links, so both reach the game's executable as usage requirements.

`fried_add_game()` takes a target name and nothing else. The paths it needs are the layout every Fried project has, relative to the caller: `build/cpp`, `project.fried`, `assets/`, `sce_sys/` for the Vita and `switch/icon.jpg` for the Switch. There are no keyword overrides, because nothing has needed to diverge from that layout.

The Haxe side needed no equivalent, since it never had a location to configure. A game's `build.hxml` adds `-cp <submodule>/src`, and the engine's own `assets/` is found relative to `src/fried/io/Assets.hx` on the classpath.

Because that layout is fixed and small, it can be generated: [Fried Project Manager](https://github.com/KoyFC/FriedProjectManager) lives in its own repository and writes a project already pinned to the engine. Nothing here knows about the tool, and the layout stays the contract between them.

## SDL2 and the native layer

SDL2 and its three companion libraries (SDL2_image, SDL2_mixer, SDL2_ttf) are found as packages rather than as paths, and initialized together in `native/platform/application.cpp`, so failing to bring one up fails `fried.Application.init()` rather than surfacing later at the first load.

`native/` is hand-written C++ glue wrapping only the SDL2 calls the engine actually makes, bound to Haxe through a small `extern class` per file. No SDL pointer type crosses into Haxe: windows, renderers and textures are tracked by integer handle (`native/handle_pool.h`). Game code never sees SDL2, only the `fried.*` types.

Two things reach Haxe as events rather than as state because SDL only reports them that way: the mouse wheel, accumulated per frame in `native/platform/mouse.cpp`, and gamepad connection, handled in `native/platform/gamepad.cpp`. Window events are translated into a small queue that Haxe drains after SDL polling is over, so a game callback never runs while SDL state is mid-update.

## Ownership in the runtime

`fried.Application` owns the SDL lifecycle, the renderer and the game loop. `fried.Window` is only a window: it has no renderer field and nothing in it knows that renderers exist. A renderer is built from a window and owned by the application, so the two are created and destroyed separately, and only one renderer exists at a time.

Textures are owned by the renderer rather than by the game. `Texture.from()` is keyed by path and returns the same instance for the same file, so a texture used by ten sprites is one `SDL_Texture`, and `Application.destroyRenderer()` destroys every texture before the renderer goes with it. A game therefore loads what it needs and writes no teardown list for it.

`destroy()` stays public, because a texture built by `Font.renderText()` has no path and a lifetime only the game knows: text rebuilt as a score changes would otherwise accumulate until shutdown. Destroying a texture drops it from the cache too, so a later `from()` on that path loads a new one instead of handing out a destroyed instance. What the cache does not do is count references, so two callers that share a path share the consequence if one of them destroys it. That is a guard rail rather than a sandbox, the same way the asset roots are.

`fried_renderer_destroy()` sweeps the texture pool before calling `SDL_DestroyRenderer()`, which is what makes the order safe rather than merely conventional. SDL frees a renderer's textures along with it, so the pool would otherwise hold dangling pointers under ids it still considers live, and a later draw or destroy would reach freed memory. With the sweep, destroying a texture after its renderer is a no-op in both layers.

The loop clears before the update callback and presents after it, so drawing code is only ever the middle of a frame that is already framed for it. A renderer is optional; with none, the loop runs exactly as it did before that step existed.

`vsync` is read back from SDL after creation rather than remembered from what was asked for, because a driver may refuse it and a loop that skipped its fps cap believing it had vsync would run unbounded. While vsync is active `targetFps` is ignored entirely: sleeping on top of vsync would push the next frame past the following vblank and halve the rate.

Input follows Unity's naming (`isKeyPressed` for held, `isKeyDown` for the frame it went down) rather than the more common convention where `IsKeyDown` means held. All three states come from comparing SDL's live state against a previous-frame snapshot the loop refreshes once per frame.

Gamepad buttons are named by position, not by label: the face buttons are `South`/`East`/`West`/`North`, so the same game code means A on an Xbox pad, cross on a PlayStation pad or a Vita, and B on a joycon. The triggers appear as both an axis and a button, because SDL reports them only as axes and a game wants them either way.

## Game objects and draw order

A `fried.scene.GameObject` is a name, a draw priority, a transform and a list of components. Behaviour comes from the components a game writes rather than from subclassing the object, and the rest of this section follows from that: a game adds a `Component` subclass, overrides `update()` or `draw()`, and never extends an engine type. An entity base class that carries `update`, `render`, a transform and a collider as its own members makes every object pay for the collider it may not want, and makes that collider unusable on anything that is not an entity.

`Transform` is a component like any other and lives in that same list, so it takes part in the same lifecycle and `getComponent(Transform)` finds it. The constructor creates it and `removeComponent` refuses to take it away, because every component that positions itself reads it. It holds position, rotation and scale and nothing else. A drawn size belongs to the `Sprite`, which takes the texture's dimensions, or those of its source region, and multiplies them by the scale. There is one source of truth, so no stored size can disagree with a scale.

The lifecycle hooks `start`, `update` and `draw` are private, and the calls into them are opened one by one with targeted `@:allow` the way `Renderer.id` is: the game object may drive its components, the scene may drive its objects, and nothing else may drive anything. A component overrides a hook and the frame calls it, but game code cannot call it by hand. Haxe's `private` is visible to subclasses from any other package, so a game's own components still override the hooks while the calls stay closed.

A `Scene` updates every object and then draws every object, in two passes rather than one. All movement therefore happens before any drawing, so an object that another object's component moved in the same frame is never drawn where it used to be. With a single pass, creation order would quietly decide which objects got a stale position.

Adds and removals happen immediately while the scene is not iterating and are deferred while it is, so a component can create or destroy objects from inside `update()` without the iteration skipping entries. Destruction is deferred whole, not just the removal from the list: `destroy()` marks the object, and its components are torn down when the scene next applies pending changes. A component that destroys its own game object would otherwise be detached from it while it was still running.

Drawing never reaches the renderer directly. A component's `draw()` submits a command to `fried.graphics.DrawQueue`, the loop flushes the queue between the update callback and `present()`, and the queue sorts before dispatching to the renderer. That is what separates the order things are drawn in from the order the code emits them in. Before the queue existed those two orders were the same thing, and changing what went on top meant moving lines.

The sort key is the pair of draw priority and submission index, ascending, so a smaller priority is further back and equal priorities keep the order they were submitted in. The submission index is unique within a frame, which makes the pair a total order: two commands never compare equal, so no sorting algorithm can produce a different picture from another. The guarantee is in the key rather than in the stability of an implementation.

Commands come from a pool that is reused between frames instead of one allocation per sprite per frame, since the cost that matters is GC pressure on a console. Each command copies the values it was given, including the contents of a `Rect`, so mutating a rect after submitting cannot alter a command already queued. The pool grows to the largest frame the program has drawn and stops there.

The draw color is ambient renderer state that `clear()` also reads, so the queue takes note of it before dispatching and puts it back if any command changed it. Otherwise the last rectangle of one frame would become the background of the next. Flushing also happens when there is no renderer, minus the sorting and the dispatch, because a queue that only drained when something could draw would grow without a ceiling.

The queue is static, like `Time` and `Input`, because only one renderer exists at a time. The application flushes it but does not own a scene: framing a frame is the loop's job, while a scene is game content and nothing about a scene says there can only be one. A game therefore drives its scene from the update callback. One consequence is worth knowing: anything drawn by calling the renderer directly from that callback is drawn before the flush, so it ends up underneath everything queued, whatever priority the queued commands carry.

`Sprite` lives in `fried.scene` rather than in `fried.graphics` so that the dependency runs one way. The scene knows what graphics are, and graphics know nothing about game objects, which is the same rule that keeps windows from knowing that renderers exist.

Application layers, parent and child hierarchies, and cameras are not implemented. A draw priority is a single flat number, and a game sets it on the object at any time, including from a component in the middle of a frame.

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

Every field is read by something. `name` and `organization` are the identity handed verbatim to `SDL_GetPrefPath()`; the engine does not sanitize them, since a silent rewrite would move a game's save directory without its author knowing. `version` and `vita.titleId` go to the Vita packaging step, which is why the version uses the `XX.XX` shape a Vita package requires, and the Switch's NACP is built from `name`, `organization` and that same `version`, which is why the Switch added no key of its own. `window.title` is the window title. Each side reads only the keys it consumes.

`fried.Project` exposes the identity as macros folded into constants, so the file is an input to the build rather than something the game ships and opens at runtime. A missing or malformed file is one fatal error, since it is one fact about the whole project; a missing field is an error per call site, so one compile reports all of them. Unknown keys are ignored, so a file declaring more than this version consumes still builds. CMake registers it in `CMAKE_CONFIGURE_DEPENDS`, so editing it cannot produce a package with stale values.

Nothing under the asset root is writable, and that is not a rule the engine chose: the Vita mounts `app0:` read-only and the Switch mounts `romfs:` read-only, so an asset API with a write side could not be implemented there anyway. Anything that has to survive a run goes through `fried.io.UserData`, whose root is resolved per platform from that identity, by SDL wherever it can answer and by the engine on the Switch, where it cannot. It throws rather than falling back to another directory if SDL cannot resolve one, because a game silently saving somewhere nobody asked for is worse than one that does not start.

## PlayStation Vita

A Vita build is a second CMake build tree configured with VitaSDK's toolchain file. That toolchain sets `VITA` and every Vita branch keys off it, so there is no platform flag of our own and no second entry point: the same `CMakeLists.txt` files build every platform.

The engine's own C++ needed exactly one branch, in `native/platform/filesystem.cpp`, for the fixed read-only mount point. Everything else in `native/` compiles unchanged, because VitaSDK ships SDL2 and its three companion libraries: the window, the event loop, the renderer, the textures, the fonts and the audio are the same calls there as on PC. The writable path needed no branch either, since VitaSDK's SDL2 implements `SDL_GetPrefPath()`.

What the port actually cost is in `cmake/Hxcpp.cmake`. hxcpp has no Vita target and its runtime is written against glibc, so `HX_LINUX` and `NEKO_LINUX` select its generic POSIX paths, `HXCPP_NO_DYNAMIC_LOADING` compiles out a `dlopen()` layer a console has no use for, and `cmake/newlib/` fills the three remaining gaps: headers newlib does not ship, POSIX its headers hide from hxcpp, and `readlink()`, which newlib declares and VitaSDK does not implement. `sys.io.Process` and `sys.net.Socket` are left out of the build, since the Vita has no subprocesses and its sockets are a Sony API rather than the BSD one hxcpp calls. Haxe code using either fails to link rather than failing on the console.

Two packaging details are easy to lose hours to. The LiveArea files in `sce_sys/` must be palette PNGs: the installer rejects a truecolor one at the end of an otherwise valid install. And `sce_sys/icon0.png` is the installer's icon, read out of the package, which makes it a different thing from the window icon a game sets at runtime.

The Vita has no keyboard or mouse, so those report nothing there; its buttons and sticks arrive as an ordinary `SDL_GameController`. Touch input is not addressed yet.

## Nintendo Switch

A Switch build is a third CMake build tree, configured with devkitPro's toolchain file. That toolchain sets `NINTENDO_SWITCH` and defines `__SWITCH__`, so the Switch keys off the console's own flags exactly as the Vita keys off `VITA` and `__vita__`. It also brings `nx_generate_nacp()` and `nx_create_nro()` with it, so `cmake/Switch.cmake` includes no SDK file, where `cmake/Vita.cmake` has to include VitaSDK's. Reaching the Switch through a hand-written devkitPro Makefile is the usual route; the toolchain file is what lets Fried keep one build system instead.

hxcpp cost the Switch almost nothing the Vita had not already paid, because both consoles run on newlib. `HX_LINUX`, `NEKO_LINUX`, `HXCPP_NO_DYNAMIC_LOADING`, the `__SNC__` on `Date.cpp` and the whole of `cmake/newlib/` are shared by the two, which is why that directory is named after the C library and not after either console. The one gap that is worse on devkitA64 is `readlink()`: VitaSDK declares it and links nothing, while devkitA64 does not declare it at all, so the shim has to declare it as well as answer it. `sys.io.Process` and `sys.net.Socket` are left out here too, the first because the console has no subprocesses and the second because libnx's sockets stay shut until a `socketInitializeDefault()` the engine never calls.

Two things diverged in `native/`. The asset root is `romfs:/assets/`, and unlike the Vita's `app0:` that mount is not automatic, so `fried_filesystem_init()` calls `romfsInit()` and a new `fried_filesystem_shutdown()` answers it, paired from `Application.shutdown()` the way the init already was from `Application.init()`. The writable path had to be branched as well, which the Vita did not need: devkitPro builds SDL on its dummy filesystem backend, so `SDL_GetPrefPath()` answers nothing and `fried.io.UserData` would throw at startup. It resolves to `sdmc:/switch/<name>/`, the flat list of one directory per homebrew application the console already keeps, which is why the organization is dropped rather than nested there.

Everything else compiles unchanged, and more of it than on the Vita. devkitPro's SDL2 drives the applet lifecycle, the controllers and the audio renderer itself, so the exit the HOME button asks for arrives as an ordinary `SDL_QUIT`, a joycon arrives as an ordinary `SDL_GameController`, and the mixer needs only the 48 kHz the console mixes at natively. Naming buttons by position is what makes the Nintendo face layout a non-event: a game asking for `South` gets B without knowing it.

Packaging is simpler than the Vita's in two ways and stricter in one. A `.nro` carries its metadata in a NACP built from fields `project.fried` already declared, so no key was added for it, and `elf2nro` receives quoted arguments, so the spaces in a path that break a Vita package are harmless here. The strict part is the icon: a 256x256 JPEG at `switch/icon.jpg`, a third format after the game's truecolor PNG and the Vita's palette PNG, and a project without one gets libnx's generic icon rather than a failure. The assets are staged into a romfs tree under the same `assets/` prefix the other two platforms use, and the `.nro` depends on the staged files rather than on the directory holding them, because `elf2nro` is handed a folder and would otherwise never notice an edited asset.

A window gets the size it asks for and the console stretches it to the whole screen, so the sandbox's 640x480 fills a 16:9 display distorted. There is no keyboard or mouse, and touch is not addressed yet. Nothing prints either: a `.nro` launched from hbmenu has nowhere to send stdout, so what is on screen is the whole report a run gives. When that report is a black screen, the first thing to rule out is the heap, which is smaller for homebrew launched from the album than for homebrew launched over a game.

## Source layout

The two source trees are split by different domains, because they are read by different people asking different questions.

`native/` is split by where an implementation comes from: `platform/` for what the operating system and the hardware provide, `graphics/` for what draws, `audio/` for what plays. Whoever opens it is asking which SDL calls the engine makes and what a new platform would have to answer for.

`src/fried/` is split by concept, because whoever opens it is writing a game and thinks in `Renderer`, `Key` and `Assets`: `fried` itself for what drives a program and the window it drives, then `fried.input`, `fried.io`, `fried.graphics`, `fried.audio` and `fried.scene`. So `fried.input.Key` is glued by `native/platform/input.cpp`, and that is deliberate rather than an oversight: a keyboard is part of the platform layer and part of input, and each tree names it the way its own reader would look for it.

Neither tree has a platform axis, and above the glue there cannot be one, since the whole point of `native/` is that the Haxe side never learns which platform it is on. Below it, a header is the contract shared by every platform, because it is what the `@:include` of the extern names.
