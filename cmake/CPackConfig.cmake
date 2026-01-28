# =============================================================================
# CPack Configuration for kDrive Linux .deb Package
# =============================================================================

if(NOT UNIX OR APPLE)
    message(STATUS "CPack DEB: Skipping (not Linux)")
    return()
endif()

message(STATUS "=== Configuring CPack for .deb packaging ===")

# -----------------------------------------------------------------------------
# Package metadata
# -----------------------------------------------------------------------------
set(CPACK_GENERATOR "DEB")
set(CPACK_PACKAGE_NAME "kdrive")
set(CPACK_PACKAGE_VENDOR "${APPLICATION_VENDOR}")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "kDrive - Infomaniak cloud sync client")
set(CPACK_PACKAGE_DESCRIPTION "kDrive desktop application for synchronizing files with Infomaniak kDrive cloud storage. Features include selective sync, file versioning, and seamless desktop integration.")
set(CPACK_PACKAGE_HOMEPAGE_URL "https://www.infomaniak.com/kdrive")
set(CPACK_PACKAGE_CONTACT "support@infomaniak.com")
set(CPACK_PACKAGE_VERSION "${KDRIVE_VERSION_FULL}")
set(CPACK_PACKAGE_VERSION_MAJOR "${KDRIVE_VERSION_MAJOR}")
set(CPACK_PACKAGE_VERSION_MINOR "${KDRIVE_VERSION_MINOR}")
set(CPACK_PACKAGE_VERSION_PATCH "${KDRIVE_VERSION_PATCH}")

# Package file name: kdrive_3.8.2.1_amd64.deb
string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _arch)
if(_arch STREQUAL "x86_64")
    set(_arch "amd64")
elseif(_arch MATCHES "aarch64|arm64")
    set(_arch "arm64")
endif()
set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}_${KDRIVE_VERSION_FULL}_${_arch}")

# -----------------------------------------------------------------------------
# Debian specific settings
# -----------------------------------------------------------------------------
set(CPACK_DEBIAN_PACKAGE_NAME "kdrive")
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Infomaniak Network SA <support@infomaniak.com>")
set(CPACK_DEBIAN_PACKAGE_SECTION "net")
set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "${_arch}")

# System dependencies (not bundled - these are low-level system libs)
set(CPACK_DEBIAN_PACKAGE_DEPENDS
    "libc6, libsecret-1-0, libxcb1, libxcb-cursor0, libxcb-icccm4, libxcb-image0, libxcb-keysyms1, libxcb-randr0, libxcb-render-util0, libxcb-shape0, libxcb-xfixes0, libxcb-xkb1, libxkbcommon0, libxkbcommon-x11-0, libfontconfig1, libfreetype6, libgl1, libegl1, libdbus-1-3"
)

# Disable automatic dependency detection (we bundle everything)
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS OFF)
set(CPACK_DEBIAN_PACKAGE_GENERATE_SHLIBS OFF)

# Post-installation scripts
set(CPACK_DEBIAN_PACKAGE_CONTROL_EXTRA
    "${CMAKE_SOURCE_DIR}/admin/linux/deb/postinst;${CMAKE_SOURCE_DIR}/admin/linux/deb/prerm;${CMAKE_SOURCE_DIR}/admin/linux/deb/postrm"
)

# -----------------------------------------------------------------------------
# Installation prefix
# -----------------------------------------------------------------------------
set(CPACK_PACKAGING_INSTALL_PREFIX "/opt/kdrive")

# -----------------------------------------------------------------------------
# Resource files
# -----------------------------------------------------------------------------
if(EXISTS "${CMAKE_SOURCE_DIR}/infomaniak/theme/license.txt")
    set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/infomaniak/theme/license.txt")
endif()
if(EXISTS "${CMAKE_SOURCE_DIR}/README.md")
    set(CPACK_RESOURCE_FILE_README "${CMAKE_SOURCE_DIR}/README.md")
endif()

# -----------------------------------------------------------------------------
# Strip binaries for release
# -----------------------------------------------------------------------------
set(CPACK_STRIP_FILES TRUE)

# =============================================================================
# Additional installation rules for .deb packaging
# (Existing targets are installed by their respective CMakeLists.txt)
# =============================================================================

# -----------------------------------------------------------------------------
# Resource files -> /opt/kdrive/resources/ and /opt/kdrive/bin/
# -----------------------------------------------------------------------------
install(FILES ${CMAKE_SOURCE_DIR}/sync-exclude-linux.lst
    DESTINATION resources
    RENAME sync-exclude.lst
    COMPONENT Runtime
)

# sync-exclude.lst also needed next to kDrive executable
install(FILES ${CMAKE_SOURCE_DIR}/sync-exclude-linux.lst
    DESTINATION bin
    RENAME sync-exclude.lst
    COMPONENT Runtime
)

install(FILES ${CMAKE_SOURCE_DIR}/litesync-exclude.lst
    DESTINATION resources
    COMPONENT Runtime
)

install(FILES ${CMAKE_SOURCE_DIR}/litesync-exclude.lst
    DESTINATION bin
    COMPONENT Runtime
)

# -----------------------------------------------------------------------------
# Desktop integration
# Note: These files go to absolute paths (outside CPACK_PACKAGING_INSTALL_PREFIX)
# -----------------------------------------------------------------------------

# Configure desktop file
configure_file(
    ${CMAKE_SOURCE_DIR}/kdrive.desktop.in
    ${CMAKE_BINARY_DIR}/kdrive.desktop
    @ONLY
)

# Update Exec path to point to /opt/kdrive/bin and use the client executable
file(READ ${CMAKE_BINARY_DIR}/kdrive.desktop _desktop_content)
string(REPLACE "Exec=@APPLICATION_EXECUTABLE@" "Exec=/opt/kdrive/bin/${APPLICATION_CLIENT_EXECUTABLE}" _desktop_content "${_desktop_content}")
string(REPLACE "Exec=${APPLICATION_EXECUTABLE}" "Exec=/opt/kdrive/bin/${APPLICATION_CLIENT_EXECUTABLE}" _desktop_content "${_desktop_content}")
file(WRITE ${CMAKE_BINARY_DIR}/kdrive.desktop "${_desktop_content}")

# Desktop file -> /usr/share/applications/
install(FILES ${CMAKE_BINARY_DIR}/kdrive.desktop
    DESTINATION /usr/share/applications
    COMPONENT Desktop
)

# Icons (various sizes for hicolor theme)
set(_icon_sizes 16 24 32 48 64 128 256 512)
foreach(_size ${_icon_sizes})
    set(_icon_file "${CMAKE_SOURCE_DIR}/infomaniak/theme/colored/${_size}-kdrive-win-icon.png")
    if(EXISTS "${_icon_file}")
        install(FILES "${_icon_file}"
            DESTINATION /usr/share/icons/hicolor/${_size}x${_size}/apps
            RENAME kdrive-win.png
            COMPONENT Desktop
        )
    endif()
endforeach()

# SVG icon for scalable
if(EXISTS "${CMAKE_SOURCE_DIR}/resources/logos/kdrive.svg")
    install(FILES ${CMAKE_SOURCE_DIR}/resources/logos/kdrive.svg
        DESTINATION /usr/share/icons/hicolor/scalable/apps
        RENAME kdrive-win.svg
        COMPONENT Desktop
    )
endif()

# -----------------------------------------------------------------------------
# PolicyKit action for privileged updates
# -----------------------------------------------------------------------------
install(FILES ${CMAKE_SOURCE_DIR}/admin/linux/deb/com.infomaniak.kdrive.policy
    DESTINATION /usr/share/polkit-1/actions
    COMPONENT Desktop
)

# Update helper script (runs with root via PolicyKit)
install(PROGRAMS ${CMAKE_SOURCE_DIR}/admin/linux/deb/kdrive-update-helper
    DESTINATION bin
    COMPONENT Runtime
)

# -----------------------------------------------------------------------------
# Bundled libraries -> /opt/kdrive/lib/
# -----------------------------------------------------------------------------

# Determine the Conan generators directory
if(DEFINED CMAKE_TOOLCHAIN_FILE AND EXISTS "${CMAKE_TOOLCHAIN_FILE}")
    get_filename_component(_conan_gen_dir "${CMAKE_TOOLCHAIN_FILE}" DIRECTORY)
else()
    set(_conan_gen_dir "${CMAKE_BINARY_DIR}")
endif()

# Macro to safely install libraries from a directory
macro(kdrive_install_libs_from _lib_dir)
    if(EXISTS "${_lib_dir}")
        file(GLOB _so_files "${_lib_dir}/*.so*")
        foreach(_so_file ${_so_files})
            get_filename_component(_so_name "${_so_file}" NAME)
            # Skip static libraries
            if(NOT "${_so_name}" MATCHES "\\.a$")
                install(FILES "${_so_file}"
                    DESTINATION lib
                    COMPONENT Libraries
                )
            endif()
        endforeach()
    endif()
endmacro()

# Install libraries from Conan packages
# log4cplus
if(DEFINED log4cplus_LIB_DIRS)
    kdrive_install_libs_from("${log4cplus_LIB_DIRS}")
endif()

# xxHash
if(DEFINED xxhash_LIB_DIRS)
    kdrive_install_libs_from("${xxhash_LIB_DIRS}")
endif()

# OpenSSL
if(DEFINED openssl_LIB_DIRS)
    kdrive_install_libs_from("${openssl_LIB_DIRS}")
endif()

# Poco
if(DEFINED poco_LIB_DIRS)
    kdrive_install_libs_from("${poco_LIB_DIRS}")
endif()

# Sentry
if(DEFINED sentry_LIB_DIRS)
    kdrive_install_libs_from("${sentry_LIB_DIRS}")
endif()

# zlib
if(DEFINED zlib_LIB_DIRS)
    kdrive_install_libs_from("${zlib_LIB_DIRS}")
endif()

# Qt6 libraries
if(DEFINED qt_LIB_DIRS)
    kdrive_install_libs_from("${qt_LIB_DIRS}")
elseif(DEFINED Qt6_DIR)
    get_filename_component(_qt_lib_dir "${Qt6_DIR}/../../.." ABSOLUTE)
    set(_qt_lib_dir "${_qt_lib_dir}/lib")
    if(EXISTS "${_qt_lib_dir}")
        kdrive_install_libs_from("${_qt_lib_dir}")
    endif()
endif()

# -----------------------------------------------------------------------------
# Qt plugins -> /opt/kdrive/plugins/
# -----------------------------------------------------------------------------

# Find Qt plugins directory
set(_qt_plugins_dir "")
if(DEFINED qt_RES_DIRS)
    # Conan-provided Qt
    foreach(_res_dir ${qt_RES_DIRS})
        if(EXISTS "${_res_dir}/plugins")
            set(_qt_plugins_dir "${_res_dir}/plugins")
            break()
        endif()
    endforeach()
endif()

if(NOT _qt_plugins_dir AND DEFINED Qt6_DIR)
    get_filename_component(_qt_plugins_dir "${Qt6_DIR}/../../../plugins" ABSOLUTE)
endif()

if(_qt_plugins_dir AND EXISTS "${_qt_plugins_dir}")
    message(STATUS "Qt plugins directory: ${_qt_plugins_dir}")

    # Essential plugins for a desktop Qt application
    set(_plugin_types
        platforms        # xcb platform plugin (required)
        platformthemes   # GTK theme integration
        imageformats     # PNG, JPEG, SVG, etc.
        iconengines      # SVG icons
        xcbglintegrations
        tls              # OpenSSL TLS backend
        sqldrivers       # SQLite for Qt SQL
        wayland-decoration-client
        wayland-graphics-integration-client
        wayland-shell-integration
    )

    foreach(_plugin_type ${_plugin_types})
        set(_plugin_src_dir "${_qt_plugins_dir}/${_plugin_type}")
        if(EXISTS "${_plugin_src_dir}")
            file(GLOB _plugin_files "${_plugin_src_dir}/*.so*")
            foreach(_plugin_file ${_plugin_files})
                install(FILES "${_plugin_file}"
                    DESTINATION plugins/${_plugin_type}
                    COMPONENT Plugins
                )
            endforeach()
        endif()
    endforeach()
else()
    message(WARNING "Qt plugins directory not found. Qt plugins will not be bundled.")
endif()

# -----------------------------------------------------------------------------
# Qt WebEngine resources -> /opt/kdrive/resources/
# -----------------------------------------------------------------------------

# Find Qt base directory
set(_qt_base_dir "")
if(DEFINED Qt6_DIR)
    get_filename_component(_qt_base_dir "${Qt6_DIR}/../../.." ABSOLUTE)
endif()

if(_qt_base_dir AND EXISTS "${_qt_base_dir}")
    # WebEngine resources (icudtl.dat, qtwebengine_resources.pak, etc.)
    set(_qt_resources_dir "${_qt_base_dir}/resources")
    if(EXISTS "${_qt_resources_dir}")
        message(STATUS "Qt WebEngine resources directory: ${_qt_resources_dir}")
        file(GLOB _webengine_resources "${_qt_resources_dir}/*.pak" "${_qt_resources_dir}/*.dat")
        foreach(_resource_file ${_webengine_resources})
            install(FILES "${_resource_file}"
                DESTINATION resources
                COMPONENT Runtime
            )
        endforeach()
    else()
        message(WARNING "Qt WebEngine resources directory not found: ${_qt_resources_dir}")
    endif()

    # QtWebEngineProcess -> /opt/kdrive/libexec/
    set(_qt_libexec_dir "${_qt_base_dir}/libexec")
    if(EXISTS "${_qt_libexec_dir}/QtWebEngineProcess")
        message(STATUS "QtWebEngineProcess found: ${_qt_libexec_dir}/QtWebEngineProcess")
        install(PROGRAMS "${_qt_libexec_dir}/QtWebEngineProcess"
            DESTINATION libexec
            COMPONENT Runtime
        )
    else()
        message(WARNING "QtWebEngineProcess not found in: ${_qt_libexec_dir}")
    endif()
else()
    message(WARNING "Qt base directory not found, WebEngine resources will not be bundled.")
endif()

# -----------------------------------------------------------------------------
# Wrapper scripts
# These scripts set up the environment (LD_LIBRARY_PATH, QT_PLUGIN_PATH)
# and execute the actual binaries
# -----------------------------------------------------------------------------

# Create wrapper script for kDrive (sync server)
file(WRITE ${CMAKE_BINARY_DIR}/kdrive-wrapper
"#!/bin/bash
# kDrive sync server launcher
KDRIVE_DIR=\"/opt/kdrive\"
export LD_LIBRARY_PATH=\"\${KDRIVE_DIR}/lib:\${LD_LIBRARY_PATH}\"
export QT_PLUGIN_PATH=\"\${KDRIVE_DIR}/plugins\"
export QT_QPA_PLATFORM_PLUGIN_PATH=\"\${KDRIVE_DIR}/plugins/platforms\"
export KDRIVE_RESOURCES_PATH=\"\${KDRIVE_DIR}/resources\"
export QTWEBENGINE_RESOURCES_PATH=\"\${KDRIVE_DIR}/resources\"
export QTWEBENGINEPROCESS_PATH=\"\${KDRIVE_DIR}/libexec/QtWebEngineProcess\"
exec \"\${KDRIVE_DIR}/bin/${APPLICATION_EXECUTABLE}.bin\" \"\$@\"
")

# Create wrapper script for kDrive_client (GUI)
file(WRITE ${CMAKE_BINARY_DIR}/kdrive-client-wrapper
"#!/bin/bash
# kDrive client (GUI) launcher
KDRIVE_DIR=\"/opt/kdrive\"
export LD_LIBRARY_PATH=\"\${KDRIVE_DIR}/lib:\${LD_LIBRARY_PATH}\"
export QT_PLUGIN_PATH=\"\${KDRIVE_DIR}/plugins\"
export QT_QPA_PLATFORM_PLUGIN_PATH=\"\${KDRIVE_DIR}/plugins/platforms\"
export KDRIVE_RESOURCES_PATH=\"\${KDRIVE_DIR}/resources\"
export QTWEBENGINE_RESOURCES_PATH=\"\${KDRIVE_DIR}/resources\"
export QTWEBENGINEPROCESS_PATH=\"\${KDRIVE_DIR}/libexec/QtWebEngineProcess\"
exec \"\${KDRIVE_DIR}/bin/${APPLICATION_CLIENT_EXECUTABLE}.bin\" \"\$@\"
")

install(PROGRAMS ${CMAKE_BINARY_DIR}/kdrive-wrapper
    DESTINATION bin
    RENAME ${APPLICATION_EXECUTABLE}-wrapper
    COMPONENT Runtime
)

install(PROGRAMS ${CMAKE_BINARY_DIR}/kdrive-client-wrapper
    DESTINATION bin
    RENAME ${APPLICATION_CLIENT_EXECUTABLE}-wrapper
    COMPONENT Runtime
)

# -----------------------------------------------------------------------------
# Include CPack module (must be last)
# -----------------------------------------------------------------------------
include(CPack)

message(STATUS "=== CPack DEB configuration complete ===")
message(STATUS "  Package: ${CPACK_PACKAGE_NAME}_${KDRIVE_VERSION_FULL}_${_arch}.deb")
message(STATUS "  Install prefix: ${CPACK_PACKAGING_INSTALL_PREFIX}")
message(STATUS "")
message(STATUS "To build the .deb package:")
message(STATUS "  1. cmake -DCPACK_PACKAGING=ON -DCMAKE_INSTALL_PREFIX=/opt/kdrive ..")
message(STATUS "  2. make")
message(STATUS "  3. cpack -G DEB")
