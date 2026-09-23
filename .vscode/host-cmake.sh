#!/bin/sh
# CMake entry point for extensions that spawn a single executable. See host-run.sh.
exec "$(dirname "$0")/host-run.sh" cmake "$@"
