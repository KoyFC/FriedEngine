# Building from the Flatpak build of VS Code

The Flatpak build of VS Code (`com.visualstudio.code`) runs inside a sandbox based on `org.freedesktop.Sdk`, with `PATH=/usr/lib/sdk/dotnet10/bin:/app/bin:/usr/bin`. Haxe is not there at all, and the sandbox's `cmake`, C++ compiler and SDL2 are the runtime's, not the ones this repository's build requires. Commands have to run on the host instead.

`.vscode/host-run.sh` does exactly that: if it detects a sandbox (`/.flatpak-info`), it forwards the command to the host with `flatpak-spawn --host`, running it under the host's login `PATH`; otherwise it runs the command unchanged. Every editor entry point goes through it, so the same checkout works in both VS Code builds with no local edits.

## What works out of the box

- The build tasks (`Build sandbox` and its three steps) and the `Run sandbox` task, whose SDL window opens on the host desktop.
- The `Debug sandbox (Flatpak VS Code)` launch configuration, which drives the host's `gdb` over `flatpak-spawn` (pick this one instead of `Debug sandbox` inside the Flatpak).
- Haxe completion and diagnostics, via `haxe.executable` in `.vscode/settings.json` pointing at `.vscode/host-haxe.sh` on Linux.

## Requirements

- The host toolchain from the README (Haxe, hxcpp, CMake, a C++17 compiler, SDL2), installed on the host, not in the sandbox.
- `gdb` on the host, for debugging.
- The Flathub package's default permissions: `--filesystem=host` and `--talk-name=org.freedesktop.Flatpak`. If they were removed, restore them with:

  ```sh
  flatpak override --user --filesystem=host com.visualstudio.code
  flatpak override --user --talk-name=org.freedesktop.Flatpak com.visualstudio.code
  ```

- The repository must live under a path that exists identically on the host, i.e. somewhere under `$HOME`. The working directory is forwarded to the host as-is, so a path that only exists inside the sandbox (under `/run/host`, for instance) will not resolve.

## Running host commands by hand

The integrated terminal is a sandbox shell, so host tools are not on its `PATH`. Prefix them:

```sh
.vscode/host-run.sh cmake --build build
.vscode/host-run.sh ./build/sandbox/fried_sandbox
```

`flatpak-spawn --host <command>` works too, but without the host login `PATH`.

## Optional settings

If you drive builds from the CMake Tools UI rather than the tasks, point it at the wrapper. Put this in the Flatpak install's **user** settings (`~/.var/app/com.visualstudio.code/config/Code/User/settings.json`) rather than in the repository, because `cmake.cmakePath` has no per-platform form and committing it would break Windows:

```json
"cmake.cmakePath": "${workspaceFolder}/.vscode/host-cmake.sh"
```

## Known limitation

`haxelib.executable` has no per-platform form either, so vshaxe's Dependencies view does not find `haxelib` inside the sandbox. Completion, diagnostics and builds are unaffected, since those go through `haxe`.
