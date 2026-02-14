# FindxxHash.cmake
# -----------------
# Find the xxHash library using pkg-config.
#
# This module defines:
#   xxHash_FOUND        - True if xxHash was found
#   xxHash_INCLUDE_DIRS - xxHash include directories
#   xxHash_LIBRARIES    - xxHash libraries
#
# and the following imported target:
#   xxHash::xxhash      - The xxHash library
#

# Try CMake config mode first (works with Conan-provided xxHash)
find_package(xxHash CONFIG QUIET)
if(xxHash_FOUND AND TARGET xxHash::xxhash)
    return()
endif()

# Fallback: use pkg-config to find the system-installed xxHash
find_package(PkgConfig QUIET)
if(PKG_CONFIG_FOUND)
    pkg_check_modules(_XXHASH QUIET libxxhash)
endif()

find_path(xxHash_INCLUDE_DIR
    NAMES xxhash.h
    PATHS ${_XXHASH_INCLUDEDIR}
    PATH_SUFFIXES xxhash
)

find_library(xxHash_LIBRARY
    NAMES xxhash
    PATHS ${_XXHASH_LIBDIR}
)

if(_XXHASH_VERSION)
    set(xxHash_VERSION "${_XXHASH_VERSION}")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(xxHash
    REQUIRED_VARS xxHash_LIBRARY xxHash_INCLUDE_DIR
    VERSION_VAR xxHash_VERSION
)

if(xxHash_FOUND AND NOT TARGET xxHash::xxhash)
    add_library(xxHash::xxhash UNKNOWN IMPORTED)
    set_target_properties(xxHash::xxhash PROPERTIES
        IMPORTED_LOCATION "${xxHash_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${xxHash_INCLUDE_DIR}"
    )
endif()

mark_as_advanced(xxHash_INCLUDE_DIR xxHash_LIBRARY)
