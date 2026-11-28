# Build profiles

A build profile is what one platform needs that the others do not: its optimization, its packaging text, its precision and the backend it uses for each [module](modules.md). Profiles live in `project.fried` under `platforms`, one per platform, so the settings that used to be scattered over a `<platform>` section, the root and several CMake files are in one place.

```yaml
modules:
  physics2d: kinematic
physics2d: {pixelsPerMeter: 32, gravity: [0, 980]}
platforms:
  pc:
    optimize: speed
    compressExecutable: true
    modules: {physics2d: box2d}
  vita: {titleId: FRIE00001, modules: {physics2d: box2d}}
  nds: {lto: true, subtitle1: Fried Engine}
  cg50: {}
```

The keys of `platforms` are the platforms the game builds for, and `nds: {}` declares one with the defaults. Declaring none, or all eight, builds everywhere. Configuring for a platform that is not declared fails, and the editor player is exempt, as it always was. `display` stays at the root, since a game has one design size: a `display` inside a profile is refused.

## Keys

| Key | Platforms | What it does |
|---|---|---|
| `precision` | all | `single` or `double` `Float`. |
| `optimize`, `lto` | all | Optimize for `speed` or `size`; link with LTO. |
| `modules` | all | The backend this platform uses for a module, over the root `modules`. |
| `compressExecutable` | pc | Packs the executable with UPX. |
| `titleId` | vita | Goes to the Vita packaging step. |
| `description` | 3ds | The SMDH description. |
| `subtitle1`, `subtitle2` | nds | The banner's second and third lines. |
| `package`, `versionCode`, `orientation` | android | The application id, its version code and its orientation. |

## How it is read

`fried_import --project-json` is the only reader of the file: CMake receives JSON that always has this shape, with each profile's `modules` already resolved (the module's default, then the root `modules`, then the profile's own). `cmake/ProjectProfile.cmake` reads the keys from it.

A file in the old layout, where `platforms` was a list and `vita:`, `nds:` and the rest were sections at the root, still builds: the importer moves them into the profiles and warns that saving the project from the editor upgrades it.
