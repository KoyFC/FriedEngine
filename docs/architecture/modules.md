# Modules

A module is a feature that does not work the same on every platform: 2D physics, 3D physics and audio. Each has backends, and each backend lists the platforms it runs on. `modules.json` at the root of the engine is the manifest.

| Module | Backends | Notes |
|---|---|---|
| `physics2d` | `kinematic` (default, everywhere), `box2d` (pc, vita, switch, 3ds, web, android) | See [2D physics with Box2D](physics-2d-box2d.md). |
| `audio` | `native` (everywhere) | On the fx-CG50 it is degraded: sounds play silently and audio files are left out. |
| `physics3d` | `none` (default), `jolt` | `jolt` is planned and cannot be chosen yet. |

A backend names the Haxe `classes` that implement it, a `native` part when it has one, and optionally the `components` only it has, `unsupportedFields`, `degraded` text for a platform where it only works as a stub, `dropAssets` for files that are left out there, and `planned`.

Backends of the same module share their components when they can: `physics2d` has `Body2D` and `Collider2D` on every platform, and `unsupportedFields` lists, by component, the settings a backend does not use, which the editor greys. A backend with components of its own would have them left out of the scenes of the platforms that do not use it.

## Choosing

A profile picks a backend with `modules`, and the root `modules` is the default for every profile. Configuring fails when a profile asks for a backend that does not run on its platform, one that is planned, or a module that does not exist, and says which key to change.

## One Haxe build, many platforms

Haxe generates one `build/cpp` for every platform, so the code cannot differ per platform. The engine therefore uses union and stubs:

- Haxe compiles the components of every backend that any declared platform uses. A backend nobody uses is dropped, and using one of its classes in game code is an error that names the module.
- CMake links the real native part on the platforms that use the backend and a stub on the others, so the binary has no Box2D where it is not used.
- `fried_import` removes the components only a backend has from the scenes of the platforms that do not use it, and warns with a count. It also leaves out the assets a degraded backend cannot use.
- A scene that still holds such a component, when the editor plays it as another platform, skips it with a warning.

## In the editor

The `schema` message carries the manifest, the backend each platform chose and the module and backend of each class. A component that a platform leaves out is shown greyed, with a warning on the object listing the platforms, and a setting its backend does not use is greyed with a tooltip naming the platforms.
