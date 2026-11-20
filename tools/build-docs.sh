#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

zensical build --strict --clean

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

haxe -cp src -D fried-project=sandbox/project.fried -D doc-gen -D no-compilation \
    -cpp "$work/cpp" --no-output --xml "$work/fried.xml" --macro "include('fried')"

haxelib run dox -i "$work/fried.xml" -o site/api \
    --include fried --exclude 'fried\.editor' \
    --title "Fried Engine API" \
    -D source-path https://github.com/KoyFC/FriedEngine/blob/main/src/ \
    -D website https://koyfc.github.io/FriedEngine/
