# Tools

A game is made with two tools that live in repositories of their own: [Fried Project Manager](https://github.com/KoyFC/FriedProjectManager) and [Fried Editor](https://github.com/KoyFC/FriedEditor). The Project Manager is where a project is created, kept in a list and built, and the Editor is where it is edited.

## Fried Project Manager

It creates projects, keeps a list of them and builds them. It is where a project starts, and the Editor is opened from it.

- **New Project** writes a whole project directory, makes it a Git repository with the engine as a submodule, and opens it. The project builds and runs as it comes out.
- **The home screen** lists the last projects opened, and reopens an existing one to change what its `project.fried` declares (see [The project file](../reference/project-file.md)).
- **It builds** a project for PC, the PlayStation Vita, the Nintendo Switch, the Nintendo 3DS, the Nintendo DS, the Casio fx-CG50 and the web, all from the same sources, and from Linux it also builds the PC game for Windows. It runs the same steps [Building](building.md) describes, with the toolchain each platform needs already chosen.
- **Open in Editor** starts Fried Editor on the project. The first time, it offers to download a Fried Editor release from GitHub, and **Editor Versions...** on the home screen lists the releases to download others.

Its documentation is at [koyfc.github.io/FriedProjectManager](https://koyfc.github.io/FriedProjectManager/).

## Fried Editor

It is where a project is edited, and the recommended way to make its scenes. It opens the folder of a project, the one with `project.fried`, and finds the engine in the project's `engine/` folder.

- **Scenes.** The viewport shows a scene without running it. A node is selected with a click and moved by dragging it, and the scene is saved as a JSON file under the project's `assets/scenes/`, which the engine only reads (see [Scene files](../architecture/scene-files.md)). A scene that has a `Node3D` opens in 3D.
- **Project settings.** The project's identity, start scene and display, saved to `project.fried`, and a page for each platform with its icon, its packaging text and its build.
- **Play.** It builds and runs the game for PC from the editor.

The engine is designed around the Editor: a game made its way has no `main` of its own and opens the scene `project.fried` names (see [Starting a game](../architecture/starting-a-game.md)). A scene can also be built in code or written by hand as JSON (see [Scene files](../architecture/scene-files.md)), but placing nodes that way is tedious, so the Editor is the recommended way to make scenes.

The first run builds the editor player from the engine, which needs Haxe, hxcpp and CMake as building a game does (see [Installing](installing.md)). It is released as an AppImage for Linux and a zip for Windows, and the Project Manager downloads it from there.

Its documentation is at [koyfc.github.io/FriedEditor](https://koyfc.github.io/FriedEditor/).

## Without the tools

Neither tool is required. [Using the engine in a game](using-in-a-game.md) is the layout the Project Manager writes, made by hand, and [Building](building.md) builds it from a terminal.
