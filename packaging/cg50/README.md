# libstdc++ with exceptions for the fx-CG50

hxcpp needs C++ exceptions, since a Haxe `throw` is a C++ `throw`, but the fxSDK builds its libstdc++ and libsupc++ with `-fno-exceptions`. A program compiled with exceptions still links against them, and then every `throw` ends in `std::terminate()`, because `__cxa_throw` itself was compiled without the unwind tables the unwinder needs to get out of it.

`build-libstdcxx.sh` rebuilds both libraries from the same GCC release as the installed `sh-elf-gcc`, configured the way the fxSDK configures them apart from `-fexceptions`, and installs them over the fxSDK's own. It builds only `libstdc++-v3`, with the compiler already installed, rather than the whole of GCC, so it takes about a minute per multilib. It checks that the configuration produces the same `bits/c++config.h` as the headers the fxSDK installed, which the libraries are then used with, and warns if not.

Both of the fxSDK's multilibs are rebuilt: the default one, which is what an fx-CG50 add-in links unless it passes `-m4-nofpu` at link time (the fxSDK's toolchain file passes it only when compiling), and `m4-nofpu`. Other add-ins built with the same fxSDK keep working, since code compiled without exceptions links against these libraries as before.

## Building and installing

This needs the [fxSDK](https://git.planet-casio.com/Lephenixnoir/fxsdk) with its `sh-elf-gcc` and libstdc++ installed, as the fxSDK's own instructions leave them, plus `curl` and `make`. Nothing needs root, since the fxSDK's sysroot belongs to the user who installed it:

```sh
packaging/cg50/build-libstdcxx.sh
```

The GCC sources are downloaded and built under `$TMPDIR/fried-cg50-libstdcxx` (`/tmp` when `TMPDIR` is unset), or under `FRIED_CG50_WORK_DIR` when it is set. A second run reuses the downloaded sources.

The fxSDK's original libraries are kept next to the new ones as `libstdc++.a.no-exceptions` and `libsupc++.a.no-exceptions`, saved the first time only, so moving them back restores the fxSDK as it was. Reinstalling `sh-elf-gcc` through GiteaPC also replaces these libraries with its own, after which the script has to run again.
