#!/bin/sh
# Runs a build command on the host when the editor is sandboxed.
#
# VS Code's Flatpak build cannot see the host toolchain (haxe, cmake, the C++
# compiler, SDL2), so commands are forwarded to the host through
# flatpak-spawn. Outside a sandbox the command runs unchanged, which keeps a
# single configuration working for both installs.
#
# `bash -lc 'exec "$0" "$@"'` preserves the arguments verbatim while running
# the command under the host's login PATH: flatpak-spawn forwards the
# sandbox PATH, which only covers /usr/bin and would miss toolchains
# installed elsewhere.
set -e

if [ -f /.flatpak-info ]; then
    exec flatpak-spawn --host --directory="$PWD" -- \
        bash -lc 'exec "$0" "$@"' "$@"
fi

exec "$@"
