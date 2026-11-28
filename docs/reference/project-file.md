# The project file

A game declares itself in a `project.fried` at its own root, in YAML (see [YAML in Fried files](yaml.md)). Each side reads only the keys it consumes, and unknown keys are ignored, so a file declaring more than this version consumes still builds. Why the file is shaped this way is in [Project file and user data](../architecture/project-file.md).

| Field | Type | Default | What it does |
|---|---|---|---|
| `name` | string | required | The identity handed verbatim to `SDL_GetPrefPath()`; the engine does not sanitize it, since a silent rewrite would move a game's save directory without its author knowing. The Switch's NACP is built from it. |
| `organization` | string | required | The other half of the identity handed to `SDL_GetPrefPath()`, and one of the inputs of the Switch's NACP. |
| `version` | string | required | Goes to the Vita packaging step, which is why it uses the `XX.XX` shape a Vita package requires, and to the Switch's NACP. |
| `platforms.vita.titleId` | string | required for a Vita build | Goes to the Vita packaging step. |
| `window.title` | string | required where the game reads it | The window title. |
| `display.mode` | `default`, `fit`, `integer`, `expand`, `pixel`, `height` or `stretch` | `default` | How the game fills the screen. |
| `display.width`, `display.height` | whole numbers above zero | required for every mode but `default`; a window opens at 640 by 480 on a computer when they are missing | The size the game is designed for. |
| `display.filter` | `nearest` or `linear` | `nearest` | How every texture is sampled when drawn at another size, whether the display or a transform scaled it: pixel art wants `nearest`, and art drawn at a higher resolution than it is shown at wants `linear`. |
| `platforms` | map of `pc`, `vita`, `switch`, `3ds`, `nds`, `cg50`, `web` and `android` to a build profile | every platform | The platforms the game builds for, each with its own settings (see [Build profiles](../architecture/build-profiles.md)). Configuring for one that is not listed fails, and the limits of the listed ones are checked on every build: a PNG over 1024 pixels a side warns when `3ds` or `nds` is listed. `pc` is every computer. An unknown name is refused, and `nds: {}` declares a platform with the defaults. The editor player is a computer build of any project and is never refused. The old layout, a list with the sections at the root, is still read with a warning. |
| `physicsRate` | integer | 60 | How many fixed steps a second the game runs; a game for a console that cannot afford them may ask for 30. |
| `vsync` | boolean | true unless it is `false` | Passed to the renderer `fried.Bootstrap.run()` creates. It is only a request: the consoles and the calculator always present at their own refresh. |
| `defaultTargetFramerate` | integer | `0`, which is no limit | The frame rate `Bootstrap` starts the loop at when vsync is off. It is read only then and only to start the game. |
| `startScene` | string | the first scene, by name | The scene the game loads when it starts. |
| `autoload` | list of strings | none | Component classes or scenes loaded once at startup, in order, and kept while the game runs, for what the whole game needs: music, a pause menu, a debug overlay. A name that is a component class is made on an object of its own, and any other is a scene file. |
| `input` | object | none | The input actions of the game, declared as data: a list of `maps`, each with a `name`, an optional `enabled` and its `actions`. See [Input](../architecture/input.md) for the format. A mistake in it is an error of the build. |
| `platforms.<p>.optimize` | `speed` or `size` | `size` on the DS, `speed` elsewhere | `size` builds for size and drops what nothing uses at link time. |
| `platforms.<p>.lto` | boolean | false | Links with link time optimization. |
| `platforms.<p>.precision` | `single` or `double` | `single` on the DS, `double` elsewhere | The width of `Float`. |
| `platforms.pc.compressExecutable` | boolean | false | Packs the computer's executable with UPX. |
| `platforms.3ds.description` | string, up to 128 characters | `Version <version>` | The SMDH's description line. |
| `platforms.nds.subtitle1` | string, up to 31 characters | the organization | The DS banner's second line. |
| `platforms.nds.subtitle2` | string, up to 31 characters | `Version <version>` | The DS banner's third line. |
| `platforms.android.package`, `.versionCode`, `.orientation` | string, whole number, string | see the Android page | The application id, version code and orientation. |
| `modules` | map of module to backend | each module's default | The backend every platform uses for a module, unless its profile says otherwise. See [Modules](../architecture/modules.md). |
| `platforms.<p>.modules` | map of module to backend | the root `modules` | The backends this platform uses. Choosing one that does not run on the platform is refused at configure time. |
| `physics2d.pixelsPerMeter` | number above zero | 32 | Pixels in a Box2D meter. |
| `physics2d.gravity` | `[x, y]` | `[0, 980]` | Box2D's gravity in pixels a second squared. |

A text too long for its package is refused at configure time rather than cut where nobody sees it. So is a build for a platform `platforms` does not list. There is one `display` for every platform: a `<platform>.display` is refused at configure time.

## Example

The sandbox's own file:

```yaml
autoload: [SandboxShell]
display:
  height: 480
  mode: height
  width: 640
name: Fried Sandbox
organization: Fried Engine
physicsRate: 50
platforms:
  nds: {lto: true}
  pc:
    modules: {physics2d: box2d}
  vita: {titleId: FRIE00001}
startScene: sandbox
version: "01.00"
window:
  title: Fried Engine sandbox !!!
```
