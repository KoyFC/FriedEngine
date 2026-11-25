# Asset roots

Assets sit under one root, split in two at runtime: `engine/`, shipped by the engine, and `game/`, shipped by the game. Engine code may read only the engine root; game code may read both.

The split exists only in the runtime layout. Each side keeps its assets in a plain `assets/` directory in its own repository, and CMake copies them into place next to the executable, so a game never writes the word `game` anywhere in its own tree. The copy is its own `ALL` target rather than a `POST_BUILD` command, since `POST_BUILD` only fires when the target relinks and an edited asset would then never reach the build tree.

`fried.io.Assets.engine()` and `game()` are macros, folded at compile time into a single constant path. That is what buys the three checks worth having:

- The file must exist in the source tree, so a typo is a compile error at the call site rather than a null load on a platform nobody tested.
- `game()` refuses any caller whose package starts with `fried`, which is the entire mechanism behind the engine/game asymmetry. There is no second class, second classpath or runtime path inspection.
- Absolute paths and `..` are rejected, so neither root can walk into the other.

Paths must be macro constants, which is what makes those checks possible on every asset reference in the program. It can be relaxed later by falling back to unverified runtime resolution, without invalidating a single existing call; the reverse would not be true.

An asset a scene file names is chosen at run time, so it goes through `Filesystem.resolveAsset(root, path)` instead. It makes the same checks the macros do, except that a missing file is found when the asset loads rather than when the program compiles: an unknown root, an absolute path and `..` are rejected. The scene file is data, so the engine/game asymmetry is not enforced here: whoever writes the file chooses the root.

The boundary is a guard rail, not a sandbox. `fried.io.Filesystem.getAssetPath()` is public and has to be, so engine code that wanted to could still build a `game/` path by hand. What the macro buys is that it cannot happen by accident, and that it is visible in review.

On Android the two roots live inside the APK, in its `assets/` folder as `engine/` and `game/`, and the asset path is empty. Nothing there is a file on disk, so `Filesystem.exists` and `Filesystem.readBytes` read through SDL on that platform, which opens a relative path out of the APK.
