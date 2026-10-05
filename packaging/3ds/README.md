# SDL2 for the Nintendo 3DS

devkitPro ships SDL 1.2 for the 3DS but not SDL2, which has had an official 3DS backend since 2.28. These are pacman packages for SDL2, SDL2_image, SDL2_mixer and SDL2_ttf, built from pinned upstream releases with devkitPro's own 3DS CMake toolchain and installed into `$DEVKITPRO/portlibs/3ds`, the same place devkitPro's packages go. Going through pacman rather than a script means root only ever runs the package manager, every file installed is owned by a package (`pacman -Qo`), and `pacman -R` removes them cleanly.

SDL2_image decodes PNG and JPEG through its bundled stb_image, and SDL2_mixer plays WAV, OGG, MP3 and FLAC through its bundled decoders, so neither depends on another library. SDL2_ttf uses devkitPro's `3ds-freetype`.

## Building and installing

This needs [devkitPro](https://devkitpro.org/) with `$DEVKITPRO` set, `makepkg` and `fakeroot`. Each package builds against the ones before it, so they are built and installed one at a time, in this order:

```sh
export PACMAN=pacman
sudo $PACMAN -S --needed libctru 3ds-cmake 3ds-pkg-config 3ds-freetype
for package in 3ds-sdl2 3ds-sdl2_image 3ds-sdl2_mixer 3ds-sdl2_ttf; do
    (cd packaging/3ds/$package && makepkg -f && sudo $PACMAN -U --noconfirm $(makepkg --packagelist)) || break
done
```

`PACMAN` names the pacman that has devkitPro's repositories, and makepkg reads it too when it checks dependencies. Set it to `dkp-pacman` where devkitPro installs it under that name, and to the full path of the system's own (`/usr/bin/pacman`) where VitaSDK is also installed, since VitaSDK puts a `pacman` of its own first on `PATH` that cannot read the system's configuration.

The installs are left out of makepkg on purpose: `makepkg -si` would do the same in one command, but it runs `sudo -k`, which discards the cached password and asks for it again for every package.
