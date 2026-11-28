# Architecture

These pages describe the decisions behind what is currently implemented, and why each one was made. It is not an API reference, which is [generated from `src/fried/`](https://koyfc.github.io/FriedEngine/api/).

- [Consuming the engine](consuming.md)
- [SDL2 and the native layer](native-layer.md)
- [Ownership in the runtime](ownership.md)
- [Input](input.md)
- [Game objects](game-objects.md)
- [The draw queue](draw-queue.md)
- [Tilemaps](tilemaps.md)
- [Text](text.md)
- [Documents in HTML and CSS](ui-documents.md)
- [Cameras](cameras.md)
- [Layers](layers.md)
- [Time](time.md)
- [Scene switching](scene-switching.md)
- [Scene files](scene-files.md)
- [Starting a game](starting-a-game.md)
- [Editor player](editor-player.md)
- [3D](3d.md)
- [Meshes, materials and models](meshes.md)
- [Collisions](collisions.md)
- [2D physics with Box2D](physics-2d-box2d.md)
- [Modules](modules.md)
- [Build profiles](build-profiles.md)
- [Asset roots](asset-roots.md)
- [Project file and user data](project-file.md)

## Build pipeline

```
Haxe  --(hxcpp)-->  generated C++  --(CMake)-->  compiler  -->  executable
```

Haxe compiles to C++ with `-D no-compilation`, which stops hxcpp before its own build tool would run (and with `-dce full`, which drops what nothing calls), and CMake compiles and links everything from there. `cmake/Hxcpp.cmake` locates the `hxcpp` haxelib and compiles its runtime sources alongside the generated code, so nothing depends on hxcpp's `Build.xml` or on `haxelib run hxcpp`.

The reason for taking that over is that CMake is then the single build system for every target platform, including the ones hxcpp has no support for. The Vita port is what proved it and the Switch is what confirmed it: the Haxe side did not change for either.

## Source layout

The two source trees are split by different domains, because they are read by different people asking different questions.

`native/` is split by where an implementation comes from: `platform/` for what the operating system and the hardware provide, `graphics/` for what draws, `audio/` for what plays. Whoever opens it is asking which SDL calls the engine makes and what a new platform would have to answer for.

`src/fried/` is split by concept, because whoever opens it is writing a game and thinks in `Renderer`, `Key` and `Assets`: `fried` itself for what drives a program and the window it drives, then `fried.input`, `fried.io`, `fried.graphics`, `fried.graphics3d`, `fried.audio`, `fried.scene` and `fried.physics`.

`fried.physics` is that split applied honestly rather than literally: it holds colliders and the queries over them and nothing else, with no bodies, no mass and no integration step, and it is still the package a game looks under for a raycast. `Layer` is in the root for that reason and `SceneLayer` is next to the `Scene` it wraps, since one is reached for by someone structuring a frame and the other by someone who already has a scene and wants it on screen. So `fried.input.Key` is glued by `native/platform/input.cpp`, and that is deliberate rather than an oversight: a keyboard is part of the platform layer and part of input, and each tree names it the way its own reader would look for it.

Neither tree has a platform axis, and above the glue there cannot be one, since the whole point of `native/` is that the Haxe side never learns which platform it is on. Below it, a header is the contract shared by every platform, because it is what the `@:include` of the extern names. Where a few lines differ, the implementation branches in place with `#if`, as the asset root does. Where a whole implementation differs, it is a sibling file named after its backend, such as `renderer_sdl.cpp` and `renderer_citro.cpp` next to `renderer.h`, so the header and every implementation of it stay in one listing and no two files share a name. `native/third_party/` holds the code the engine takes from elsewhere unchanged, stb_image and stb_truetype, which only the fx-CG50 compiles.
