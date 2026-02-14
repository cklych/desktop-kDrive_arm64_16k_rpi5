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
# CPack configuration for generating .deb packages
# --------------------------------------------------------------------------

if(NOT UNIX OR APPLE)
    return()
endif()

# Package metadata
set(CPACK_PACKAGE_NAME "${PACKAGE}")
set(CPACK_PACKAGE_VERSION "${KDRIVE_VERSION_FULL}")
set(CPACK_PACKAGE_VERSION_MAJOR "${KDRIVE_VERSION_MAJOR}")
set(CPACK_PACKAGE_VERSION_MINOR "${KDRIVE_VERSION_MINOR}")
set(CPACK_PACKAGE_VERSION_PATCH "${KDRIVE_VERSION_PATCH}")
set(CPACK_PACKAGE_VENDOR "${APPLICATION_VENDOR}")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${APPLICATION_NAME} - Desktop synchronization client")
set(CPACK_PACKAGE_DESCRIPTION
    "${APPLICATION_NAME} allows you to synchronize your Infomaniak kDrive files with your desktop computer. \
It keeps your files up-to-date across all your devices automatically.")
set(CPACK_PACKAGE_HOMEPAGE_URL "https://www.infomaniak.com/kdrive")
set(CPACK_PACKAGE_CONTACT "Infomaniak Network SA <support@infomaniak.com>")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/LICENSE")

# --------------------------------------------------------------------------
# DEB-specific settings
# --------------------------------------------------------------------------
set(CPACK_GENERATOR "DEB")
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Infomaniak Network SA <support@infomaniak.com>")
set(CPACK_DEBIAN_PACKAGE_SECTION "net")
set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
set(CPACK_DEBIAN_PACKAGE_HOMEPAGE "https://www.infomaniak.com/kdrive")

# Architecture detection
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|amd64")
    set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "amd64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
    set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "arm64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "armv7")
    set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "armhf")
else()
    set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "${CMAKE_SYSTEM_PROCESSOR}")
endif()

# Dependencies
set(CPACK_DEBIAN_PACKAGE_DEPENDS
    "libfuse2 | libfuse3-3, libsqlite3-0, libsecret-1-0, zlib1g")

# Disable auto shlibdeps (bundled libs may confuse it)
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS OFF)

# Package naming: infomaniakdrive-client_3.8.1.5_amd64.deb
set(CPACK_DEBIAN_FILE_NAME "${CPACK_PACKAGE_NAME}_${CPACK_PACKAGE_VERSION}_${CPACK_DEBIAN_PACKAGE_ARCHITECTURE}.deb")

# Control scripts
set(_debian_scripts_dir "${CMAKE_SOURCE_DIR}/admin/linux/debian")
if(EXISTS "${_debian_scripts_dir}/postinst")
    set(CPACK_DEBIAN_PACKAGE_CONTROL_EXTRA
        "${_debian_scripts_dir}/postinst;${_debian_scripts_dir}/prerm")
endif()

# Strip binaries for release packages
if(CMAKE_BUILD_TYPE MATCHES "Release|RelWithDebInfo")
    set(CPACK_STRIP_FILES TRUE)
endif()

include(CPack)
