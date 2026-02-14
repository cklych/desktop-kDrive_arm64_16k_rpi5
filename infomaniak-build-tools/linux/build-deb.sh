#!/usr/bin/env bash

#
# Infomaniak kDrive - Desktop
# Copyright (C) 2023-2025 Infomaniak Network SA
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# --------------------------------------------------------------------------
# Build a .deb package for kDrive.
#
# This script assumes the project has already been built (cmake + make).
# It runs 'cpack' inside the build directory to produce the .deb.
#
# Usage:
#   build-deb.sh [-d <build-directory>]
#
# If -d is not specified, it defaults to <src-dir>/build-linux/build.
# --------------------------------------------------------------------------

set -e

program_name="$(basename "$0")"

function display_help {
    echo "$program_name [-h] [-d <build-directory>]"
    echo "  Generate a .deb package from an existing kDrive build."
    echo "where:"
    echo "  -h  Show this help text."
    echo "  -d <build-directory>"
    echo "      Path to the CMake build directory. Defaults to <src-dir>/build-linux/build."
}

# Determine source directory (parent of infomaniak-build-tools/)
script_dir="$(cd "$(dirname "$0")" && pwd)"
src_dir="$(cd "$script_dir/../.." && pwd)"

build_dir=""

while :
do
    case "$1" in
        -d | --build-dir)
            build_dir="$2"
            shift 2
            ;;
        -h | --help)
            display_help
            exit 0
            ;;
        --) shift; break ;;
        -*) echo "Error: Unknown option: $1" >&2; exit 1 ;;
        *) break ;;
    esac
done

if [ -z "$build_dir" ]; then
    build_dir="$src_dir/build-linux/build"
fi

if [ ! -d "$build_dir" ]; then
    echo "Error: Build directory does not exist: $build_dir"
    echo "Please build the project first, then run this script."
    exit 1
fi

if [ ! -f "$build_dir/CPackConfig.cmake" ]; then
    echo "Error: CPackConfig.cmake not found in $build_dir"
    echo "Make sure the project was configured with CPack support."
    exit 1
fi

echo "=== Building .deb package ==="
echo "Build directory: $build_dir"
echo

cd "$build_dir"
cpack -G DEB -C RelWithDebInfo

echo
echo "=== Done ==="
echo "Package(s) generated in: $build_dir"
ls -lh "$build_dir"/*.deb 2>/dev/null || echo "Warning: No .deb file found."
