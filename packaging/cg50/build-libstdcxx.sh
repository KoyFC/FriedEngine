#!/usr/bin/env bash
# Rebuilds the fxSDK's libstdc++ and libsupc++ with C++ exceptions, for every
# multilib its sh-elf-gcc has, and installs them over the fxSDK's own. See
# README.md.

set -euo pipefail

for tool in sh-elf-gcc sh-elf-g++ sh-elf-ar sh-elf-ranlib sh-elf-nm sh-elf-strip curl tar make; do
    if ! command -v "$tool" >/dev/null; then
        echo "error: $tool not found on PATH" >&2
        exit 1
    fi
done

gcc_version=$(sh-elf-gcc -dumpversion)
work_dir=${FRIED_CG50_WORK_DIR:-${TMPDIR:-/tmp}/fried-cg50-libstdcxx}
source_dir=$work_dir/gcc-$gcc_version

mkdir -p "$work_dir"

if [[ ! -d $source_dir ]]; then
    archive=$work_dir/gcc-$gcc_version.tar.xz
    if [[ ! -f $archive ]]; then
        echo "Downloading GCC $gcc_version sources..."
        curl -fL -o "$archive.part" "https://ftp.gnu.org/gnu/gcc/gcc-$gcc_version/gcc-$gcc_version.tar.xz"
        mv "$archive.part" "$archive"
    fi
    echo "Extracting GCC $gcc_version sources..."
    tar -xf "$archive" -C "$work_dir"
fi

build_triplet=$("$source_dir/config.guess")
headers_dir=$(realpath "$(dirname "$(sh-elf-gcc -print-file-name=libstdc++.a)")/../include/c++/$gcc_version/sh3eb-elf")

# Each line of -print-multi-lib is "<directory>;@<flag>@<flag>...". The fxSDK
# links without the CPU flags it compiles with, so an fx-CG50 add-in gets the
# default (SH3) multilib rather than m4-nofpu unless it asks otherwise.
while IFS=';' read -r multilib_dir multilib_flags; do
    target_flags="-mb ${multilib_flags//@/ -}"
    install_dir=$(realpath "$(dirname "$(sh-elf-gcc $target_flags -print-file-name=libstdc++.a)")")
    if [[ $multilib_dir == . ]]; then
        build_dir=$work_dir/build/default
    else
        build_dir=$work_dir/build/$multilib_dir
    fi

    if [[ ! -f $install_dir/libstdc++.a ]]; then
        echo "error: no libstdc++.a in $install_dir; install the fxSDK's sh-elf-gcc with libstdc++ first" >&2
        exit 1
    fi

    # Configured the way the fxSDK configures it, apart from the exceptions,
    # which yields a bits/c++config.h identical to the one the fxSDK installed.
    # Only libstdc++-v3 is built, against the compiler already installed,
    # rather than the whole of GCC. --without-headers is what makes configure
    # skip the link tests a compiler with no libc of its own cannot pass.
    rm -rf "$build_dir"
    mkdir -p "$build_dir"

    echo "Configuring libstdc++-v3 ($multilib_dir)..."
    (cd "$build_dir" && "$source_dir/libstdc++-v3/configure" \
        --build="$build_triplet" \
        --host=sh3eb-elf \
        --target=sh3eb-elf \
        --with-cross-host="$build_triplet" \
        --with-target-subdir=sh3eb-elf \
        --prefix="$work_dir/unused-prefix" \
        --disable-multilib \
        --without-headers \
        --disable-shared \
        --enable-clocale=generic \
        --enable-libstdcxx-allocator \
        --disable-libstdcxx-verbose \
        --enable-cxx-flags=-fexceptions \
        CC="sh-elf-gcc $target_flags" \
        CXX="sh-elf-g++ $target_flags -nostdinc++" \
        CFLAGS="-O2" \
        CXXFLAGS="-O2" \
        AR=sh-elf-ar \
        RANLIB=sh-elf-ranlib \
        NM=sh-elf-nm \
        > configure.log 2>&1) || { echo "error: configure failed, see $build_dir/configure.log" >&2; exit 1; }

    installed_config=$headers_dir/$multilib_dir/bits/c++config.h
    if ! cmp -s "$build_dir/include/sh3eb-elf/bits/c++config.h" "$installed_config"; then
        echo "warning: this configuration differs from the fxSDK's installed headers ($installed_config)" >&2
    fi

    echo "Building libstdc++-v3 ($multilib_dir)..."
    make -C "$build_dir" -j"$(getconf _NPROCESSORS_ONLN)" > "$build_dir/make.log" 2>&1 || { echo "error: build failed, see $build_dir/make.log" >&2; exit 1; }

    # The fxSDK's own copies are kept once, so reinstalling the toolchain is
    # not the only way back.
    for library in libstdc++.a libsupc++.a; do
        if [[ ! -f $install_dir/$library.no-exceptions ]]; then
            cp "$install_dir/$library" "$install_dir/$library.no-exceptions"
        fi
    done

    cp "$build_dir/src/.libs/libstdc++.a" "$build_dir/libsupc++/.libs/libsupc++.a" "$install_dir/"
    sh-elf-strip -g "$install_dir/libstdc++.a" "$install_dir/libsupc++.a"

    echo "Installed libstdc++.a and libsupc++.a with exceptions into $install_dir"
done < <(sh-elf-gcc -print-multi-lib)
