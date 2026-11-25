# Android

## Requirements

- The Android NDK r27d (27.3.13750724), with its CMake toolchain file at `<ndk>/build/cmake/android.toolchain.cmake`.
- An Android SDK folder holding `platforms/android-35` and `build-tools/35.0.1`, which supply `android.jar`, `aapt2`, `zipalign` and `apksigner`.
- A JDK (21 or newer) for `javac`, `jar`, `java` and `keytool`.
- The Project Manager downloads all of these into its tools folder, on Linux.

No Gradle is involved: CMake runs `javac`, `d8`, `aapt2`, `jar`, `zipalign` and `apksigner` itself.

## Building

```sh
haxe build.hxml
cmake -S . -B build/android \
    -DCMAKE_TOOLCHAIN_FILE=<ndk>/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 \
    -DFRIED_ANDROID_SDK=<sdk> -DFRIED_JAVA_HOME=<jdk>
cmake --build build/android
```

`ANDROID_HOME` and `JAVA_HOME` are read when the two `-D` options are left out. Only `arm64-v8a` is built.

### Output

`build/android/<target>.apk`, signed with Android's debug key (`~/.android/debug.keystore`, made on the first build when it is not there). Its library is stored uncompressed and aligned to 16 KB pages, which devices with 16 KB pages require.

The APK holds `lib/arm64-v8a/libmain.so`, which is the game, the engine and SDL2 in one library, `classes.dex` with SDL's Java and a `FriedActivity` that loads that library, and the two asset roots as `assets/engine/` and `assets/game/`. SDL reads a relative path out of the APK, so the asset path is empty on this platform.

### Running

```sh
adb install -r build/android/fried_sandbox.apk
adb logcat -s SDL SDL/APP Exception AndroidRuntime DEBUG
```

## project.fried

An optional `android` section:

| Key | Meaning |
|---|---|
| `package` | The name the device knows the game by, such as `com.example.mygame`. Left out, it is `com.<organization>.<name>` lowercased, with everything but letters, digits and underscores taken out. |
| `versionCode` | The whole number stores compare to tell versions apart. Defaults to 1. |
| `orientation` | `landscape` (the default) or `portrait`. The phone may be turned either way within it. |

The icon is `android/icon.png`, 192 by 192 pixels. A project without one gets the default launcher icon.
