#!/usr/bin/env bash

#
# Infomaniak kDrive - Desktop
# Build script for Raspberry Pi 5 / Raspbian ARM64 with 16k page kernel.
# Uses system-installed libraries instead of Conan/podman.
#
# Prerequisites:
#   sudo apt install -y build-essential cmake ninja-build git \
#       libgl1-mesa-dev libsqlite3-dev libsecret-1-dev libdbus-1-dev \
#       libssl-dev zlib1g-dev libxxhash-dev liblog4cplus-dev \
#       libpoco-dev libzip-dev libcppunit-dev \
#       qt6-base-dev qt6-webengine-dev qt6-5compat-dev qt6-svg-dev qt6-svg-plugins \
#       qt6-wayland qt6-tools-dev qt6-tools-dev-tools qt6-l10n-tools \
#       pkg-config extra-cmake-modules shared-mime-info
#
# Sentry-native must be compiled separately (see build_sentry below).
#

set -eo pipefail

script_directory_path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
export KDRIVE_SRC_DIR="${KDRIVE_SRC_DIR:-}"
source "$script_directory_path/build-utils.sh"
set -u

program_name="$(basename "$0")"
git_dir="$(get_default_src_dir)"
build_type="RelWithDebInfo"
jobs="$(nproc)"
skip_sentry=0

function display_help {
    echo "$program_name [-h] [-d git-directory] [-j jobs] [-t build-type] [--skip-sentry]"
    echo "  Build kDrive desktop for Raspbian ARM64 (16k page kernel)."
    echo "  Uses system libraries instead of Conan."
    echo ""
    echo "Options:"
    echo "  -h              Show this help text."
    echo "  -d <dir>        Set the git directory path. Defaults to '$git_dir'."
    echo "  -j <N>          Number of parallel build jobs. Defaults to $(nproc)."
    echo "  -t <type>       Build type: Debug, Release, RelWithDebInfo. Defaults to '$build_type'."
    echo "  --skip-sentry   Skip building sentry-native (use if already installed)."
}

function check_log4cplus_installed {
    if [ -f /usr/local/lib/liblog4cplusU.so ] && [ -d /usr/local/lib/cmake/log4cplus ]; then
        return 0
    fi
    return 1
}

function build_log4cplus {
    echo "=== Building log4cplus from source (with Unicode + 16k page flags) ==="

    local log4cplus_version="2.1.2"
    local log4cplus_src="/tmp/log4cplus-${log4cplus_version}"
    local log4cplus_build="${log4cplus_src}/build"

    if check_log4cplus_installed; then
        echo "log4cplus (Unicode) already installed at /usr/local/lib/liblog4cplusU.so — skipping."
        echo "  (use 'sudo rm -rf /usr/local/lib/liblog4cplus* /usr/local/lib/cmake/log4cplus /usr/local/include/log4cplus' to force rebuild)"
        return 0
    fi

    if [ ! -d "$log4cplus_src" ]; then
        echo "Downloading log4cplus ${log4cplus_version}..."
        cd /tmp
        curl -sL "https://github.com/log4cplus/log4cplus/releases/download/REL_2_1_2/log4cplus-${log4cplus_version}.tar.xz" -o log4cplus.tar.xz
        tar xf log4cplus.tar.xz
        rm log4cplus.tar.xz
    fi

    mkdir -p "$log4cplus_build"
    cd "$log4cplus_build"

    cmake .. \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DUNICODE=ON \
        -DBUILD_SHARED_LIBS=ON \
        -DLOG4CPLUS_BUILD_TESTING=OFF \
        -DLOG4CPLUS_QT5=OFF \
        -DWITH_UNIT_TESTS=OFF \
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384" \
        -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"

    make -j"$jobs"

    echo "Installing log4cplus (requires sudo)..."
    sudo make install
    sudo ldconfig

    echo "log4cplus ${log4cplus_version} (Unicode) installed successfully."
}

function check_sentry_installed {
    if [ -f /usr/local/lib/libsentry.so ] && [ -f /usr/local/lib/cmake/sentry/sentry-config.cmake ]; then
        return 0
    fi
    return 1
}

function build_sentry {
    echo "=== Building sentry-native from source (with 16k page flags) ==="

    local sentry_version="0.7.17"
    local sentry_src="/tmp/sentry-native-${sentry_version}"
    local sentry_build="${sentry_src}/build"

    if check_sentry_installed; then
        echo "sentry-native already installed at /usr/local/lib/libsentry.so — skipping."
        echo "  (use 'sudo rm -rf /usr/local/lib/libsentry* /usr/local/lib/cmake/sentry' to force rebuild)"
        return 0
    fi

    if [ ! -d "$sentry_src" ]; then
        echo "Downloading sentry-native ${sentry_version}..."
        cd /tmp
        curl -sL "https://github.com/getsentry/sentry-native/releases/download/${sentry_version}/sentry-native.zip" -o sentry-native.zip
        unzip -qo sentry-native.zip -d "$sentry_src"
        rm sentry-native.zip
    fi

    mkdir -p "$sentry_build"
    cd "$sentry_build"

    cmake .. \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DSENTRY_BACKEND=inproc \
        -DSENTRY_BUILD_EXAMPLES=OFF \
        -DSENTRY_BUILD_TESTS=OFF \
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384" \
        -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"

    make -j"$jobs"

    echo "Installing sentry-native (requires sudo)..."
    sudo make install
    sudo ldconfig

    echo "sentry-native installed successfully."
}

function build_kdrive {
    echo "=== Building kDrive desktop (${build_type}) ==="

    local build_dir="${git_dir}/build-raspbian"
    mkdir -p "$build_dir"
    cd "$build_dir"

    export KDRIVE_USE_SYSTEM_LIBS=1

    # /usr/local first so our custom log4cplus/sentry are found before Debian packages
    cmake \
        -G Ninja \
        -DCMAKE_BUILD_TYPE="$build_type" \
        -DCMAKE_PREFIX_PATH="/usr/local;/usr" \
        -DKDRIVE_THEME_DIR="${git_dir}/infomaniak" \
        -DKDRIVE_USE_SYSTEM_LIBS=ON \
        -DBUILD_UNIT_TESTS=OFF \
        -DBUILD_EXTENSIONS=OFF \
        -DCMAKE_INSTALL_PREFIX=/usr \
        "${git_dir}"

    echo "=== Compiling with ${jobs} jobs ==="
    echo "    (incremental: only changed files will be recompiled)"
    cmake --build . -j "$jobs"

    # Copy sync-exclude.lst next to binaries (required at runtime for ParmsDb init)
    cp "${git_dir}/sync-exclude-linux.lst" "${build_dir}/bin/sync-exclude.lst"

    echo ""
    echo "=== Build successful ==="
    echo "Binaries are in: ${build_dir}/bin/"
    echo ""
    echo "To install: cd ${build_dir} && sudo ninja install"
}

function build_appimage {
    echo "=== Building AppImage ==="

    local build_dir="${git_dir}/build-raspbian"
    local appdir="${build_dir}/AppDir"
    local linuxdeploy_bin="${build_dir}/linuxdeploy-aarch64.AppImage"
    local linuxdeploy_qt="${build_dir}/linuxdeploy-plugin-qt-aarch64.AppImage"
    local output_dir="${git_dir}"

    # Download linuxdeploy if not present
    if [ ! -f "$linuxdeploy_bin" ]; then
        echo "Downloading linuxdeploy for aarch64..."
        curl -sL "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-aarch64.AppImage" -o "$linuxdeploy_bin"
        chmod +x "$linuxdeploy_bin"
    fi

    if [ ! -f "$linuxdeploy_qt" ]; then
        echo "Downloading linuxdeploy-plugin-qt for aarch64..."
        curl -sL "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-aarch64.AppImage" -o "$linuxdeploy_qt"
        chmod +x "$linuxdeploy_qt"
    fi

    # Install into AppDir
    rm -rf "$appdir"
    cd "$build_dir"
    DESTDIR="$appdir" ninja install

    # Copy sync-exclude list
    mkdir -p "$appdir/usr/bin"
    cp "${git_dir}/sync-exclude-linux.lst" "$appdir/usr/bin/sync-exclude.lst"

    # Copy shared libraries that are not auto-detected
    mkdir -p "$appdir/usr/lib"
    cp -P /usr/local/lib/liblog4cplusU.so* "$appdir/usr/lib/"
    cp -P /usr/local/lib/libsentry.so* "$appdir/usr/lib/"

    # Copy wayland platform plugins (linuxdeploy-plugin-qt may not auto-detect them)
    local qt6_plugins="/usr/lib/aarch64-linux-gnu/qt6/plugins"
    if [ -d "$qt6_plugins/platforms" ]; then
        mkdir -p "$appdir/usr/plugins/platforms"
        cp -P "$qt6_plugins/platforms/libqwayland"*.so "$appdir/usr/plugins/platforms/" 2>/dev/null || true
    fi
    if [ -d "$qt6_plugins/wayland-shell-integration" ]; then
        cp -P -r "$qt6_plugins/wayland-shell-integration" "$appdir/usr/plugins/" 2>/dev/null || true
        cp -P -r "$qt6_plugins/wayland-decoration-client" "$appdir/usr/plugins/" 2>/dev/null || true
        cp -P -r "$qt6_plugins/wayland-graphics-integration-client" "$appdir/usr/plugins/" 2>/dev/null || true
    fi

    # Remove kDrivecmd if present (not needed)
    rm -f "$appdir/usr/bin/kDrivecmd"

    # Icon for linuxdeploy (needs to be at root of AppDir)
    cp "$appdir/usr/share/icons/hicolor/512x512/apps/kdrive-win.png" "$appdir/"

    # Set environment for linuxdeploy
    export LD_LIBRARY_PATH="$appdir/usr/lib:/usr/local/lib:${LD_LIBRARY_PATH:-}"
    export QMAKE=/usr/bin/qmake6
    export OUTPUT="kDrive-aarch64.AppImage"
    unset UPDATE_INFORMATION 2>/dev/null || true
    unset LDAI_UPDATE_INFORMATION 2>/dev/null || true

    # Run linuxdeploy (deploy only, no appimage output yet)
    cd "$output_dir"
    NO_APPSTREAM=1 "$linuxdeploy_bin" --appimage-extract-and-run \
        --appdir "$appdir" \
        -e "$appdir/usr/bin/kDrive" \
        -i "$appdir/kdrive-win.png" \
        -d "$appdir/usr/share/applications/kDrive_client.desktop" \
        --plugin qt

    # Replace AppRun symlink with a script that sets argv[0] correctly.
    # The kDrive binary uses argv[0].parent_path() + "usr/bin" when APPIMAGE is set,
    # but argv[0] resolves to the AppImage path, not the mounted AppDir.
    rm -f "$appdir/AppRun"
    cat > "$appdir/AppRun" << 'APPRUN_EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
# Use exec -a to set argv[0] to $HERE/AppRun (AppDir root).
# The kDrive binary does: workingDir = parent_path(argv[0]) + "usr/bin"
# so argv[0] must resolve to the AppDir root, not usr/bin/kDrive.
exec -a "$HERE/AppRun" "$HERE/usr/bin/kDrive" "$@"
APPRUN_EOF
    chmod +x "$appdir/AppRun"

    # Package AppImage using appimagetool
    local appimagetool_bin="${build_dir}/appimagetool-aarch64.AppImage"
    if [ ! -f "$appimagetool_bin" ]; then
        echo "Downloading appimagetool for aarch64..."
        curl -sL "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-aarch64.AppImage" -o "$appimagetool_bin"
        chmod +x "$appimagetool_bin"
    fi
    ARCH=aarch64 "$appimagetool_bin" --appimage-extract-and-run --no-appstream "$appdir" "kDrive-aarch64.AppImage"

    local appimage_file
    appimage_file=$(ls -1 kDrive*.AppImage 2>/dev/null | head -1)
    if [ -n "$appimage_file" ]; then
        echo ""
        echo "=== AppImage created: ${output_dir}/${appimage_file} ==="
    else
        echo "ERROR: AppImage was not created."
        return 1
    fi
}

function verify_elf_alignment {
    echo "=== Verifying ELF page alignment ==="
    local build_dir="${git_dir}/build-raspbian"
    local fail=0

    for binary in "${build_dir}/bin/kDrive" "${build_dir}/bin/kDrive_client"; do
        if [ -f "$binary" ]; then
            local align
            align=$(readelf -l "$binary" 2>/dev/null | grep LOAD | head -1 | awk '{print $NF}')
            if [ "$align" = "0x1000" ]; then
                echo "  FAIL (4k pages): $binary"
                fail=1
            else
                echo "  OK   ($align): $binary"
            fi
        fi
    done

    if [ "$fail" -eq 1 ]; then
        echo "WARNING: Some binaries have 4k page alignment and will NOT work on a 16k kernel."
        return 1
    else
        echo "All binaries have correct page alignment for 16k kernel."
    fi
}

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            display_help
            exit 0
            ;;
        -d|--git-dir)
            git_dir="$2"
            shift 2
            ;;
        -j|--jobs)
            jobs="$2"
            shift 2
            ;;
        -t|--type)
            build_type="$2"
            shift 2
            ;;
        --skip-sentry)
            skip_sentry=1
            shift
            ;;
        --)
            shift
            break
            ;;
        -*|--*)
            echo "Error: Unknown option: $1" >&2
            display_help
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

echo "============================================="
echo " kDrive Desktop — Raspbian ARM64 Build"
echo " Source:     $git_dir"
echo " Build type: $build_type"
echo " Jobs:       $jobs"
echo "============================================="
echo ""

# Step 1: Build log4cplus with Unicode support (Debian package lacks wchar_t symbols)
build_log4cplus

echo ""

# Step 2: Build sentry-native if needed
if [ "$skip_sentry" -eq 0 ]; then
    build_sentry
else
    echo "Skipping sentry-native build (--skip-sentry)."
    if ! check_sentry_installed; then
        echo "WARNING: sentry-native not found at /usr/local/lib/libsentry.so"
        echo "         The build will likely fail. Remove --skip-sentry to build it."
    fi
fi

echo ""

# Step 3: Build kDrive
build_kdrive

echo ""

# Step 4: Verify ELF alignment
verify_elf_alignment

echo ""

# Step 5: Build AppImage
build_appimage

echo ""
echo "Done. To re-build after code changes, simply re-run this script."
echo "Ninja will only recompile changed files (incremental build)."
