# YAML in Fried files

The project file, the scenes and the import settings are written in YAML, in the small subset the engine reads. The subset is a superset of JSON, so a file that is still JSON reads the same, and a tool can write either. The editor and the project manager convert a project when they open it (see [Moving a project from JSON](#moving-a-project-from-json)).

```yaml
# Comments start with a # that follows a space or begins a line.
name: Fried Sandbox
version: "01.00"
display:
  mode: height
  width: 640
  height: 480
autoload: [SandboxShell]
nodes:
  - type: Sprite
    id: player
    texture: {root: game, path: sprite.png}
```

## What is read

- Maps (`key: value`) and lists (`- item`) in blocks, indented with spaces. A tab that indents a line is an error. A list may sit at the indent of the key it belongs to.
- An item of a list can be a map that starts on the line of its dash, with the other keys under the first.
- `{a: 1, b: [2, 3]}` and `[1, 2]`, which may span lines and have no trailing comma. Everything JSON can write can be written this way.
- Text plain, `'in single quotes'` (`''` is a quote) or `"in double quotes"` with the escapes of JSON, `\uXXXX` and surrogate pairs included. A quoted string stays on one line.
- A plain value is `null` (also `~` or nothing), `true` or `false`, a whole number that fits 32 bits, a number with a point or an exponent, or else text. A number that reads as text is quoted: `"01.00"`, since `01.00` is the number 1.
- Comments, and a single `---` at the start.

## What is not

Anchors and aliases (`&`, `*`), tags (`!`), complex keys (`? `), block scalars (`|`, `>`), directives, several documents in a file and a key twice in one map are refused with a message that says so, at a line and column.

## The same file in both

A tool that writes the files, such as the editor, writes maps in block form and short lists and maps of plain values in one line when they fit in 80 columns, with the keys of a scene in the order a person reads them: `version`, `name`, `camera` and `nodes` for the file, and `type`, `id`, `name` and `instance` first with `children` last for a node. It quotes only the text that would otherwise read as another kind of value.

## Moving a project from JSON

`fried_migrate <project directory>` from FriedCore, which the editor and the project manager run when they open a project that has any, rewrites `project.fried`, the `.scene.json` files of `assets/` as `.scene.yaml` and the `.import` sidecars that are JSON. The originals are copied to `.fried/json-backup/<date and time>/` first, and a file that cannot be converted is left as it was and reported. `.fried/` belongs in a project's `.gitignore`.

## Where it is read

`project.fried` is read by the build, which has `fried_import --project-json` write it as JSON for CMake, and by the macros of `fried.Project`, with `fried.io.Yaml`. A scene is read at build time by `fried_import`, which compiles it for the game (see [Scene files](../architecture/scene-files.md#compiled-scenes)). The sidecars are read by `fried_import` too.
