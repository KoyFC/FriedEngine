# Consuming the engine

A game includes one file and calls one function, `fried_add_game()`. `cmake/FriedEngine.cmake` resolves every path from its own location rather than from `CMAKE_SOURCE_DIR`, and that is the whole reason the engine works as a submodule: nothing in it requires the engine to be the top-level project.

`sandbox/CMakeLists.txt` is those same two lines with a different path to `cmake/`, so the sandbox takes the path an external game takes instead of a private one, and a change that would break a game breaks the sandbox first.

A consumer therefore never repeats the list of `native/*.cpp`, the four SDL2 packages, where the hxcpp haxelib lives, the link fixups each console needs, or the location of either asset root. It still writes `cmake_minimum_required`, `project()` and its own build-type defaults, because those are the consumer's policy rather than the engine's.

`fried::engine` is the engine's C++ as a static library. It can be one because `native/` includes nothing but SDL2 and the standard library, not a single hxcpp header, so it needs none of the defines the generated code is compiled with and it builds once per build tree instead of once per game. `native/` is its `PUBLIC` include root, which is what the `@:include` of every extern resolves against, and the SDL2 targets are `PUBLIC` links, so both reach the game's executable as usage requirements.

`fried_add_game()` takes a target name and nothing else. The paths it needs are the layout every Fried project has, relative to the caller: `build/cpp`, `project.fried`, `assets/`, `sce_sys/` for the Vita and `switch/icon.jpg` for the Switch. There are no keyword overrides, because nothing has needed to diverge from that layout.

The Haxe side needed no equivalent, since it never had a location to configure. A game's `build.hxml` adds `-cp <submodule>/src`, and the engine's own `assets/` is found relative to `src/fried/io/Assets.hx` on the classpath.

Because that layout is fixed and small, it can be generated: [Fried Project Manager](https://github.com/KoyFC/FriedProjectManager) lives in its own repository and writes a project already pinned to the engine. Nothing here knows about the tool, and the layout stays the contract between them.

A scene editor, [FriedEditor](https://github.com/KoyFC/FriedEditor), is planned in a repository of its own, and the engine's share of that work is tracked in [`docs/editor-roadmap.md`](../development/editor-roadmap.md).
