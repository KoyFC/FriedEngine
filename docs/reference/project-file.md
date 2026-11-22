# The project file

A game declares itself in a `project.fried` at its own root, in JSON. Each side reads only the keys it consumes, and unknown keys are ignored, so a file declaring more than this version consumes still builds. Why the file is shaped this way is in [Project file and user data](../architecture/project-file.md).

| Field | Type | Default | What it does |
|---|---|---|---|
| `name` | string | required | The identity handed verbatim to `SDL_GetPrefPath()`; the engine does not sanitize it, since a silent rewrite would move a game's save directory without its author knowing. The Switch's NACP is built from it. |
| `organization` | string | required | The other half of the identity handed to `SDL_GetPrefPath()`, and one of the inputs of the Switch's NACP. |
| `version` | string | required | Goes to the Vita packaging step, which is why it uses the `XX.XX` shape a Vita package requires, and to the Switch's NACP. |
| `vita.titleId` | string | required for a Vita build | Goes to the Vita packaging step. |
| `window.title` | string | required where the game reads it | The window title. |
| `display.mode` | `default`, `fit`, `integer`, `expand`, `pixel`, `height` or `stretch` | `default` | How the game fills the screen. |
| `display.width`, `display.height` | whole numbers above zero | required for every mode but `default`; a window opens at 640 by 480 on a computer when they are missing | The size the game is designed for. |
| `display.filter` | `nearest` or `linear` | `nearest` | How every texture is sampled when drawn at another size, whether the display or a transform scaled it: pixel art wants `nearest`, and art drawn at a higher resolution than it is shown at wants `linear`. |
| `platforms` | list of `pc`, `vita`, `switch`, `3ds`, `nds`, `cg50` and `web` | every platform | The platforms the game builds for. Configuring for one that is not listed fails, and the limits of the listed ones are checked on every build: a PNG over 1024 pixels a side warns when `3ds` or `nds` is listed, and the game's audio files that the build leaves out warn when `cg50` is. `pc` is every computer. An empty list or an unknown name is refused. The editor player is a computer build of any project and is never refused. |
| `physicsRate` | integer | 60 | How many fixed steps a second the game runs; a game for a console that cannot afford them may ask for 30. |
| `vsync` | boolean | true unless it is `false` | Passed to the renderer `fried.Bootstrap.run()` creates. It is only a request: the consoles and the calculator always present at their own refresh. |
| `defaultTargetFramerate` | integer | `0`, which is no limit | The frame rate `Bootstrap` starts the loop at when vsync is off. It is read only then and only to start the game. |
| `startScene` | string | the first scene, by name | The scene the game loads when it starts. |
| `autoload` | list of strings | none | Scenes loaded once at startup, in order, and kept while the game runs, for what the whole game needs: music, a pause menu, a debug overlay. |
| `3ds.description` | string, up to 128 characters | `Version <version>` | The SMDH's description line. |
| `nds.subtitle1` | string, up to 31 characters | the organization | The DS banner's second line. |
| `nds.subtitle2` | string, up to 31 characters | `Version <version>` | The DS banner's third line. |

A text too long for its package is refused at configure time rather than cut where nobody sees it. So is a build for a platform `platforms` does not list. There is one `display` for every platform: a `<platform>.display` is refused at configure time.

## Example

The sandbox's own file:

```json
{
	"display": {
		"height": 480,
		"mode": "height",
		"width": 640
	},
	"name": "Fried Sandbox",
	"organization": "Fried Engine",
	"version": "01.00",
	"vita": {
		"titleId": "FRIE00001"
	},
	"window": {
		"title": "Fried Engine sandbox !!!"
	}
}
```
