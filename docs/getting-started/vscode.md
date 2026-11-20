# VS Code

Install the recommended extensions when prompted (C/C++, CMake Tools, Haxe & Neko). **Ctrl+Shift+B** runs the default build task, which regenerates the C++ from Haxe, configures CMake and builds; **F5** builds and launches under the debugger.

CMake Tools auto-configure on open is disabled on purpose, because configuring has to happen after the Haxe generation step. Use the build task, not the CMake Tools sidebar.

There is one debug configuration per system, picked once from the Run and Debug view: **Debug sandbox (Linux)** launches under `gdb`, and **Debug sandbox (Windows)** under the Visual Studio debugger, building with Visual Studio as [Windows, on Windows](building.md#windows-on-windows) does, in its Debug configuration. On Windows the build task builds Debug too, so it is the same build F5 launches.

IntelliSense follows the PC build of the system VS Code runs on, through the **Linux** or **Win32** configuration the C/C++ extension picks by name. Both read SDL2's headers from `build/_deps/`, where a configure copies them from the cache, so they need the sandbox configured once; Linux also looks in `/usr/include/SDL2` for a build with `FRIED_SYSTEM_SDL2=ON`. On Windows, hxcpp's headers come from the haxelib repository under `%HAXEPATH%`. Either way, the files only a console compiles, such as `native/graphics/renderer_citro.cpp`, show errors under it. For those, pick the **Nintendo 3DS** configuration (*C/C++: Select a Configuration*), which reads the flags from `build/3ds/compile_commands.json` and so needs that build tree configured first.

### Building from the Flatpak build of VS Code

The Flatpak build of VS Code (`com.visualstudio.code`) runs inside a sandbox based on `org.freedesktop.Sdk`, with `PATH=/usr/lib/sdk/dotnet10/bin:/app/bin:/usr/bin`. Haxe is not there at all, and the sandbox's `cmake`, C++ compiler and SDL2 are the runtime's, not the ones this repository's build requires. Commands have to run on the host instead.

`.vscode/host-run.sh` does exactly that: if it detects a sandbox (`/.flatpak-info`), it forwards the command to the host with `flatpak-spawn --host`, running it under the host's login `PATH`; otherwise it runs the command unchanged. Every editor entry point goes through it, so the same checkout works in both VS Code builds with no local edits.

### What works out of the box

- The build tasks (`Build sandbox` and its three steps) and the `Run sandbox` task, whose SDL window opens on the host desktop.
- The `Debug sandbox (Flatpak VS Code)` launch configuration, which drives the host's `gdb` over `flatpak-spawn` (pick this one instead of `Debug sandbox` inside the Flatpak).
- Haxe completion and diagnostics, via `haxe.executable` in `.vscode/settings.json` pointing at `.vscode/host-haxe.sh` on Linux.

### Requirements

- The host toolchain from [Installing](installing.md) (Haxe, hxcpp, CMake, a C++17 compiler, SDL2), installed on the host, not in the sandbox.
- `gdb` on the host, for debugging.
- The Flathub package's default permissions: `--filesystem=host` and `--talk-name=org.freedesktop.Flatpak`. If they were removed, restore them with:

  ```sh
  flatpak override --user --filesystem=host com.visualstudio.code
  flatpak override --user --talk-name=org.freedesktop.Flatpak com.visualstudio.code
  ```

- The repository must live under a path that exists identically on the host, i.e. somewhere under `$HOME`. The working directory is forwarded to the host as-is, so a path that only exists inside the sandbox (under `/run/host`, for instance) will not resolve.

### Running host commands by hand

The integrated terminal is a sandbox shell, so host tools are not on its `PATH`. Prefix them:

```sh
.vscode/host-run.sh cmake --build build
.vscode/host-run.sh ./build/sandbox/fried_sandbox
```

`flatpak-spawn --host <command>` works too, but without the host login `PATH`.

### Optional settings

If you drive builds from the CMake Tools UI rather than the tasks, point it at the wrapper. Put this in the Flatpak install's **user** settings (`~/.var/app/com.visualstudio.code/config/Code/User/settings.json`) rather than in the repository, because `cmake.cmakePath` has no per-platform form and committing it would break Windows:

```json
"cmake.cmakePath": "${workspaceFolder}/.vscode/host-cmake.sh"
```

### Known limitation

`haxelib.executable` has no per-platform form either, so vshaxe's Dependencies view does not find `haxelib` inside the sandbox. Completion, diagnostics and builds are unaffected, since those go through `haxe`.
