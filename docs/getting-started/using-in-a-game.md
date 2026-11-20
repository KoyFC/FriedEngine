# Using the engine in a game

[Fried Project Manager](https://github.com/KoyFC/FriedProjectManager) writes all of this for you, and that is the recommended route; [Fried Editor](https://github.com/KoyFC/FriedEditor) is then the recommended way to make its scenes (see [Tools](tools.md)). What follows is what it produces, for a project set up by hand or for reading what a generated one contains.

The engine is consumed as a Git submodule:

```sh
git submodule add https://github.com/KoyFC/FriedEngine.git engine
```

The game's `CMakeLists.txt` needs two lines for it:

```cmake
cmake_minimum_required(VERSION 3.20)
project(MyGame LANGUAGES CXX)

include(${CMAKE_CURRENT_SOURCE_DIR}/engine/cmake/FriedEngine.cmake)

fried_add_game(my_game)
```

and its `build.hxml` points at the submodule's source:

```
-cp engine/src
-cp src
-main Main
-cpp build/cpp
-D no-compilation
```

`fried_add_game()` expects the layout those two files imply, relative to the project root: `build/cpp` for the generated C++, a `project.fried` declaring the game's identity, an `assets/` for the game's own assets, a `sce_sys/` for a Vita build, a `switch/icon.jpg` for a Switch one, a `3ds/icon.png` for a 3DS one and, optionally, a `cg50/icon-uns.png` and `cg50/icon-sel.png` (92x64, the menu icon unselected and selected) for an fx-CG50 one. It then builds with the same commands the sandbox does.
