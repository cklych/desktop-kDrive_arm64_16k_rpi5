# cmake/raspbian-system-libs.cmake
# --------------------------------
# Include file for building on Raspbian ARM64 with system libraries.
# Usage: cmake -DKDRIVE_USE_SYSTEM_LIBS=ON ...
#        (this file is included from the top-level CMakeLists.txt)
#
# Relaxes version constraints for system-provided libraries that are
# slightly older than what the CI runners use, but remain API-compatible
# (same major version, patch-level differences only).
#
# Raspbian Trixie ships:
#   - Poco 1.13.0   (project requests >= 1.13.3) — bugfix-only delta
#   - log4cplus 2.0.8 (project requests >= 2.1.2) — same 2.x API surface

message(STATUS "KDRIVE_USE_SYSTEM_LIBS: Relaxing dependency version constraints for system libraries")

# Debian system packages export their CMake imported targets for configuration "None" only.
# Map all standard build types to "None" so that IMPORTED_LOCATION is found.
set(CMAKE_MAP_IMPORTED_CONFIG_DEBUG None NoConfig "")
set(CMAKE_MAP_IMPORTED_CONFIG_RELEASE None NoConfig "")
set(CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO None NoConfig "")
set(CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL None NoConfig "")

# Override find_package to relax specific version requirements
macro(find_package name)
    set(_kdrive_args ${ARGN})
    set(_kdrive_name "${name}")

    if("${_kdrive_name}" STREQUAL "Poco")
        # Replace version 1.13.3 with 1.13.0
        list(FIND _kdrive_args "1.13.3" _kdrive_idx)
        if(NOT _kdrive_idx EQUAL -1)
            list(REMOVE_AT _kdrive_args ${_kdrive_idx})
            list(INSERT _kdrive_args ${_kdrive_idx} "1.13.0")
        endif()
    elseif("${_kdrive_name}" STREQUAL "log4cplus")
        # log4cplus built with -DUNICODE=ON exports target log4cplusU, not log4cplus.
        # No version relaxation needed — we compile 2.1.2 from source.
    endif()

    _find_package(${_kdrive_name} ${_kdrive_args})

    # After finding log4cplus, create a wrapper target so that log4cplus::log4cplus
    # resolves to the Unicode variant log4cplus::log4cplusU.
    # (ALIAS cannot be used on IMPORTED targets, so we use an INTERFACE library.)
    if("${_kdrive_name}" STREQUAL "log4cplus")
        if(TARGET log4cplus::log4cplusU AND NOT TARGET log4cplus::log4cplus)
            add_library(log4cplus::log4cplus INTERFACE IMPORTED)
            set_target_properties(log4cplus::log4cplus PROPERTIES
                INTERFACE_LINK_LIBRARIES log4cplus::log4cplusU
            )
        endif()
    endif()
endmacro()
