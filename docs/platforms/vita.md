# PlayStation Vita

## Building

```sh
cmake -S . -B build/vita -DCMAKE_TOOLCHAIN_FILE=$VITASDK/share/vita.toolchain.cmake
cmake --build build/vita
```

That produces `build/vita/sandbox/fried_sandbox.vpk`, which can be installed using VitaShell. Keep spaces out of both the project path and the build tree path: VitaSDK's packaging step passes them to `vita-pack-vpk` unquoted, and the failure surfaces as CMake failing to copy `<target>.vpk.out`.
