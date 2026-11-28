# Troubleshooting

Each entry repeats what the page it links to says about that symptom.

## The window does not open, or there is no sound, on Linux

A display or audio system whose headers are missing is left out of SDL2 without an error, and the game then fails to open a window or plays nothing, so install all of them.

See [On Linux, for Linux](installing.md#on-linux-for-linux).

## The frame rate stays at the target under XWayland

Under XWayland, an X11 window in a Wayland session, a renderer asked for vsync is created without it, reports `isVsyncEnabled` as false, and the loop paces frames to `Application.targetFps` instead. The cost is that the rate is the target rather than the display's: a 144 Hz screen gets 60 unless the game raises `targetFps`.

See [SDL2 and the native layer](../architecture/native-layer.md).

## The compiler or CMake is not found on Windows with w64devkit

None of them is on the system `PATH`, so nothing outside that folder finds them on its own, VS Code included: every build has to be run from the terminal that `w64devkit.exe`, inside the folder, opens, which has them on its `PATH` for as long as it stays open.

See [On Windows, for Windows](installing.md#on-windows-for-windows).

## ccache is installed but nothing is cached

Visual Studio's generator ignores compiler launchers, so use `-G Ninja` with w64devkit or build the player with `/MP` and no cache. With w64devkit, `ccache` has to be on the `PATH` of the terminal `w64devkit.exe` opens. The player looks for it when it is configured, so configure again after installing it.

See [Rebuilding faster](building.md#rebuilding-faster).

## There is no log to read on Windows

A Release build opens no console window, so its log is only visible from a Debug one (`-DCMAKE_BUILD_TYPE=Debug`) or under Wine, which prints it to the terminal either way.

See [Windows, from Linux](building.md#windows-from-linux).

## The Vita build fails copying `<target>.vpk.out`

Keep spaces out of both the project path and the build tree path: VitaSDK's packaging step passes them to `vita-pack-vpk` unquoted, and the failure surfaces as CMake failing to copy `<target>.vpk.out`.

See [PlayStation Vita](../platforms/vita.md#building).

## Nothing is logged on the Switch

Nothing it logs is visible on the console, so the scene on screen is the whole report a run gives.

See [Nintendo Switch](../platforms/switch.md#building).

## The 3DS build runs silent

Sound needs the console's DSP firmware dumped to `sdmc:/3ds/dspfirm.cdc` (by DSP1 on a console; any file of that name satisfies Azahar), and without it the program runs silent.

See [Nintendo 3DS](../platforms/3ds.md#running).

## Half of the top screen flashes black in Azahar

In Azahar, use its OpenGL renderer: on Vulkan the right half of the top screen flashes black.

See [Nintendo 3DS](../platforms/3ds.md#running).

## Some triangles are not drawn on the 3DS

Triangles may use only half of citro2d's vertex buffer in a frame, so the triangles past that are the ones dropped while sprites, text and the other screen keep the other half.

See [Nintendo 3DS](../platforms/3ds.md).

## `The scene file is version 0` on the DS

`MinSizeRel` is safe on the DS only because `cmake/Hxcpp.cmake` builds the hxcpp code at `-O2` regardless: at `-Oz` GCC stops aligning string literals, hxcpp reads a header word in front of each one, and the ARM9 turns the unaligned load into garbage, so strings are taken for the wrong encoding and scene files fail to parse with `The scene file is version 0`. If that error ever appears on a DS build, check the optimization level of the hxcpp sources first.

See [The build type and strings](../platforms/nds.md#the-build-type-and-strings).

## The web page is stuck on loading

A browser will not load those from a `file://` address, so opening the page with a double click leaves it stuck on loading. Serve the folder over HTTP instead.

See [Web](../platforms/web.md#running).

## The web page shows the old build

After a rebuild, reload with Ctrl+Shift+R, or the browser keeps the old files.

See [Web](../platforms/web.md#running).
