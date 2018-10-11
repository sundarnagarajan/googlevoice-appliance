#!/bin/bash

# Timestamp identifier for DEBs and firmware file
DEB_FW_TS="20180910"
# URL for Ubuntu Raspberry server pre-installed image
UBUNTU_RASPI_IMAGE_URL="http://cdimage.ubuntu.com/ubuntu/releases/18.04/release/ubuntu-18.04.1-preinstalled-server-armhf+raspi2.img.xz"
# Hostname to set for new installed image - preferably set in ENVIRONMENT instead
#ASTERISK_HOSTNAME=ubuntu
MOUNT_TOP_DIR=/media

# ------------------------------------------------------------------------
# Do not need to change unless Ubuntu image format changes
# ------------------------------------------------------------------------
# Number of partitions DISK_DEV must have (exact)
DISK_DEV_NUM_PARTITIONS=2
DISK_DEV_BOOT_PARTNUM=1
DISK_DEV_ROOT_PARTNUM=2

# DISK_DEV_PART_LABELS: array variables - access values as ${DISK_DEV_PART_LABELS[x]}
DISK_DEV_PART_LABELS[1]=system-boot
DISK_DEV_PART_LABELS[2]=cloudimg-rootfs

# ------------------------------------------------------------------------
# Do not need to change unless download URLs, number, names of DEB or 
# firmware files or name of firmware top-level dir changes in the future
# ------------------------------------------------------------------------
DEB_URL_PREFIX="http://archive.raspberrypi.org/debian/pool/main/r/raspberrypi-firmware"
FIRMWARE_URL_PREFIX="$DEB_URL_PREFIX"
DEB_NAMES="libraspberrypi-bin_1 libraspberrypi-dev_1 libraspberrypi-doc_1 libraspberrypi0_1 raspberrypi-bootloader_1 raspberrypi-kernel-headers_1 raspberrypi-kernel_1"
# Only FIRST element of FIRMWARE_NAMES is used to extract boot dir
# check_urls and 00_check_urls.sh check ALL elements of FIRMWARE_NAMES
FIRMWARE_NAMES="raspberrypi-firmware_1"
# Note extracted dir name ends in -1 and not _1 !
FIRMWARE_EXTRACT_DIR="raspberrypi-firmware-1.${DEB_FW_TS}"

# ------------------------------------------------------------------------
# Do not need to change anything below this
# ------------------------------------------------------------------------
# Top level dir containing dirs:
#   asterisk_build asterisk_prep download ubuntu_prep
TOP_DIR=$(readlink -e ${PROG_DIR}/..)

# Make DISK_DEV a fully qualified path
if [ -n "$DISK_DEV" ]; then
    echo "$DISK_DEV" | grep -q '^/dev'
    if [ $? -ne 0 ]; then
        DISK_DEV="/dev/${DISK_DEV}"
    fi
fi

# Directories that must be present under $TOP_DIR
REQUIRED_DIRS="scripts ubuntu_prep"
MOUNT_BOOT_DIR=${MOUNT_TOP_DIR}/${DISK_DEV_PART_LABELS[$DISK_DEV_BOOT_PARTNUM]}
MOUNT_ROOT_DIR=${MOUNT_TOP_DIR}/${DISK_DEV_PART_LABELS[$DISK_DEV_ROOT_PARTNUM]}

# Directories that we mounted - to unmount on exit / error
MOUNTED_DIRS_TO_UNMOUNT=""

# Directories inside root partition
ROOT_PART_TOP_DIR=/root/asterisk
ROOT_PART_DEB_DIR=${ROOT_PART_TOP_DIR}/ubuntu_prep/debs
ROOT_PART_PKGS_DIR=${ROOT_PART_TOP_DIR}/packages
ROOT_PART_ASTERISK_BUILD_DIR=${ROOT_PART_TOP_DIR}/asterisk_build

# Files containing lists of packages installed
# Will be under $ROOT_PART_PKGS_DIR
# All are COMPLETE lists; To find differences, use join -v{1|2} command
PKGLIST_00_UBUNTU=00_base_ubuntu
PKGLIST_01_RASPI_UPDATES=01_base_raspi_updates
PKGLIST_02_ASTERISK_PREREQ=02_asterisk_prereqs
PKGLIST_03_ASTERISK_BUILT=03_asterisk_built
PKGLIST_04_ASTERISK_PREREQ_DEV_KEEP=04_asterisk_devpkgs_keep
PKGLIST_05_ASTERISK_PREREQ_DEV_ALL=05_asterisk_devpkgs_all
PKGLIST_06_ASTERISK_PREREQ_DEV_DEL=06_asterisk_devpkgs_delete
PKGLIST_07_ASTERISK_DEB_DEPENDS=07_asterisk_deb_depends

# Other configurable items on booted asterisk
ASTERISK_SEVICES_TO_DISABLE="snapd.service snapd.seeded.service snapd.core-fixup.service snapd.autoimport.service"
ASTERISK_BUILD_PKGS_MINIMAL="build-essential bison flex sqlite3"

# LC_ALL=C required to make sort behave correctly!
export LC_ALL=C

# Related to asterisk DEB
ASTERISK_DEB_PKG_SOURCE="https://github.com/naf419/asterisk.git"
# Make sure version is larger than what apt-cache policy asterisk returns
# Otherwise repo asterisk will update asterisk from DEB on apt-get update!
# and GV will not work!
# version needs to start with '1:' because that is what Ubuntu uses!
ASTERISK_DEB_PKG_VERSION="1:15.0.0-b300c563e8M"
