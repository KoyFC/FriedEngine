# Platforms

Linux is the default build, described in [Building](../getting-started/building.md); each page here covers one other platform. Each page starts with what to install for it, then how to build.

| Platform | Built from | Drawing | 3D meshes | Verified on |
|---|---|---|---|---|
| Linux | Linux | SDL2's renderer | Depth buffer through SDL's `opengl` driver; triangles in painter's order when SDL has no OpenGL context with a depth buffer | GCC on Fedora |
| Windows | Windows with MSVC or MinGW-w64, or Linux with MinGW-w64 | SDL2's renderer | As on Linux | MSVC and MinGW-w64 on Windows, MinGW-w64 from Linux (run under Wine) |
| [PlayStation Vita](vita.md) | Linux | SDL2's renderer | Depth buffer through GXM inside SDL's renderer, with `libshacccg.suprx` in `ur0:data/`; triangles in painter's order without it | Not stated |
| [Nintendo Switch](switch.md) | Linux | SDL2's renderer | Depth buffer through SDL's `opengles2` driver; its backend has only been built, not run | Not stated |
| [Nintendo 3DS](3ds.md) | Linux | citro2d | Depth buffer through citro3d | Azahar |
| [Nintendo DS](nds.md) | Linux | The DS's 3D engine on the top screen, the CPU on the bottom one | The DS's 3D engine | melonDS |
| [Casio fx-CG50](cg50.md) | Linux | The CPU, into gint's frame | Triangles in painter's order, with no further 3D support | A calculator |
| [Web](web.md) | Linux | SDL2's Emscripten port | Triangles in painter's order | Not stated |

- [PlayStation Vita](vita.md)
- [Nintendo Switch](switch.md)
- [Nintendo 3DS](3ds.md)
- [Nintendo DS](nds.md)
- [Casio fx-CG50](cg50.md)
- [Web](web.md)

## Features

| Symbol | Meaning |
|---|---|
| ✅ | Implemented, in code shared with other platforms |
| 🛠️ | Implemented, with a backend of its own for the platform |
| ⏳ | Pending |
| ❌ | Not supported |

| Feature | Linux | Windows | Vita | Switch | 3DS | DS | fx-CG50 | Web |
|---|---|---|---|---|---|---|---|---|
| 2D drawing | ✅ | ✅ | ✅ | ✅ | 🛠️ | 🛠️ | 🛠️ | ✅ |
| Text | ✅ | ✅ | ✅ | ✅ | ✅ | 🛠️ | 🛠️ | ✅ |
| 3D meshes | ✅ | ✅ | 🛠️ | ✅ | 🛠️ | 🛠️ | ✅ | ✅ |
| 3D depth buffer | ✅ | ✅ | 🛠️ | ✅ | 🛠️ | 🛠️ | ❌ | ⏳ |
| Sounds | ✅ | ✅ | ✅ | ✅ | ✅ | 🛠️ | ❌ | ✅ |
| Music | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ |
| Gamepad | ✅ | ✅ | ✅ | ✅ | 🛠️ | 🛠️ | ❌ | ✅ |
| Keyboard and mouse | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | 🛠️ | ✅ |
| Touch | ✅ | ✅ | ✅ | ✅ | ✅ | 🛠️ | ❌ | ✅ |
| Two screens | ❌ | ❌ | ❌ | ❌ | 🛠️ | 🛠️ | ❌ | ❌ |
| Physics | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| User data that persists | ✅ | ✅ | ✅ | ✅ | ✅ | 🛠️ | 🛠️ | ❌ |
| Editor play mode | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

Text on the fx-CG50 and the DS is drawn with a pixel font. The fx-CG50 keyboard is its keypad. The Switch 3D backend has only been built, not run, and a Web game keeps its user data in memory until the page closes.
