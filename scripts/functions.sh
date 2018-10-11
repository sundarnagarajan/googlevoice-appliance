#!/bin/bash
# ------------------------------------------------------------------------
# Information and information from:
# https://www.invik.xyz/linux/Ubuntu-Server-18-04-1-RasPi3Bp/
#
# Asterisk (gvsip) build instructions form:
# https://community.freepbx.org/t/how-to-guide-for-google-voice-with-freepbx-14-asterisk-gvsip-ubuntu-18-04/50933
# ------------------------------------------------------------------------

if [ -n "$BASH_SOURCE" ]; then
    PROG_PATH=${PROG_PATH:-$(readlink -e $BASH_SOURCE)}
else
    PROG_PATH=${PROG_PATH:-$(readlink -e $0)}
fi
PROG_DIR=${PROG_DIR:-$(dirname ${PROG_PATH})}
PROG_NAME=${PROG_NAME:-$(basename ${PROG_PATH})}
SCRIPT_DIR="${PROG_DIR}"

# Source config
if [ -f "${SCRIPT_DIR}/config.sh" ]; then
    . "${SCRIPT_DIR}/config.sh"
    if [ $? -ne 0 ]; then
        echo "Error sourcing config: ${SCRIPT_DIR}/config.sh"
        exit 1
    fi
else
    echo "config not found: ${SCRIPT_DIR}/config.sh"
    exit 1
fi

function cleanup {
    # Called on exit / error
    cd /
    for d in $MOUNTED_DIRS_TO_UNMOUNT
    do
        echo "Unmounting $d"
        umount -l $d
    done
}

# ------------------------------------------------------------------------
# Setup exit trap
# ------------------------------------------------------------------------
trap cleanup EXIT

function show_config {
    if [ -n "$DISK_DEV" ]; then
        echo "DISK_DEV: $DISK_DEV"
    else
        echo "DISK_DEV not set"
    fi
    echo "DISK_DEV partitions:"
    echo "    DISK_DEV must have exactly $DISK_DEV_NUM_PARTITIONS partitions"
    echo "    DISK_DEV partition labels expected:"
    for i in $(seq 1 ${#DISK_DEV_PART_LABELS[@]})
    do
        echo "        Partition ${i}: ${DISK_DEV_PART_LABELS[$i]}"
    done
    echo "DEB_FW_TS: $DEB_FW_TS"
    echo "Directories:"
    echo "    TOP_DIR: $TOP_DIR"
    echo "    MOUNT_TOP_DIR: $MOUNT_TOP_DIR"
    echo "    MOUNT_BOOT_DIR: $MOUNT_BOOT_DIR"
    echo "    MOUNT_ROOT_DIR: $MOUNT_ROOT_DIR"
}


function is_valid_url() {
    # $1: URL
    # Returns:
    #   0: if URL is a valid HTTP(S) URL
    #   1: otherwise
    curl -s -L -f -I "$1" 1>/dev/null 2>&1
    return $?
}

function check_urls {
    echo "Checking URLs"
    errors=0
    # Ubuntu Raspi image URL
    echo -n "    UBUNTU_RASPI_IMAGE_URL: "
    is_valid_url "$UBUNTU_RASPI_IMAGE_URL"
    [ $? -eq 0 ] && echo "OK" || echo "Not found"

    # DEBS
    echo "    DEB URLs:"
    for p in $DEB_NAMES
    do
        echo -n "        $p : "
        is_valid_url "$DEB_URL_PREFIX/${p}.${DEB_FW_TS}-1_armhf.deb"
        [ $? -eq 0 ] && echo "OK" || (echo "Not found"; errors=1)
    done
    # Firmware
    echo "    Firmware URLs:"
    for p in $FIRMWARE_NAMES
    do
        echo -n "        $p : "
        is_valid_url "$FIRMWARE_URL_PREFIX/${p}.${DEB_FW_TS}.orig.tar.gz"
        [ $? -eq 0 ] && echo "OK" || (echo "Not found"; errors=1)
    done
    return $errors
}

function must_be_root {
    # Must be root
    if [ $(id -u) -ne 0 ]; then
        echo "Must be root. Execute with sudo"
        return 1
    fi
}

function partition_label {
    # Needs root (blkid)
    # $1: fully qualified partition path
    blkid -s LABEL -o value $1
}

function check_target_dev {
    echo "Checking DISK_DEV"
    if [ -z "$DISK_DEV" ]; then
        echo "    DISK_DEV not set"
        return 1
    fi
    if [ ! -b "$DISK_DEV" ]; then
        echo "    DISK_DEV not a block device: $DISK_DEV"
        return 1
    fi
    echo "    DISK_DEV is a block device: $DISK_DEV"
    # target dev must have EXACTLY two partitions
    num_partitions=$(ls -1 ${DISK_DEV}?* 2>/dev/null | wc -l)
    if [ $num_partitions -ne $DISK_DEV_NUM_PARTITIONS ]; then
        echo "    DISK_DEV does not have exactly $DISK_DEV_NUM_PARTITIONS partitions: $num_partitions"
        return 1
    fi
    echo "    $DISK_DEV has exactly $DISK_DEV_NUM_PARTITIONS partitions"
    # Check each partition is a block device (is this needed?)
    for f in $(ls -1 ${DISK_DEV}?* 2>/dev/null)
    do
        if [ ! -b $f ]; then
            echo "    Not a block device: $f"
            return 1
        else
            echo "    $f is a block device"
        fi
    done
    # Check partition labels
    local part_label=""
    for i in $(seq 1 $DISK_DEV_NUM_PARTITIONS)
    do
        part_label=$(partition_label ${DISK_DEV}$i)
        if [ -z "$part_label" ]; then
            echo "    ${DISK_DEV}: Partition $i has no label"
            return 1
        fi
        if [ "$part_label" != "${DISK_DEV_PART_LABELS[$i]}" ]; then
            echo "    Partition $i label is wrong: $part_label - should be ${DISK_DEV_PART_LABELS[$i]}"
            return 1
        fi
        echo "    ${DISK_DEV}$i label is ${DISK_DEV_PART_LABELS[$i]}"
    done
}

function check_reqd_dirs {
    # Params: list of required dirs
    for d in $@
    do
        if [ ! -d "${TOP_DIR}/$d" ]; then
            echo "Required dir not found: ${TOP_DIR}/$d"
            return 1
        fi
    done
}

function proceed_if_yes {
    # $1: message
    echo ""
    echo ""
    echo -n "${1}. ENTER YES to continue: "
    read a
    if [ "$a" != "YES" ]; then
        return 1
    fi
    echo ""
    echo ""
}

function confirm_target_disk {
    parted $DISK_DEV print
    proceed_if_yes "Is this the correct target device"
}

function is_mounted {
    if [ -z "$1" ]; then
        return 1
    fi
    mount | awk "\$3==\"$1\" {print \$3}" | fgrep -q $1
    return $?
}

function dir_is_empty {
    if [ -z "$1" ]; then
        return 1
    fi
    
    if [ ! -d "$1" ]; then
        return 1
    fi

    [ $(ls -1A "$1" | wc -l) -eq 0 ] && return $?
}

function write_image {
    # DISK_DEV must be set: can be sdX or /dev/sdX
    if [ -z "$DISK_DEV" ]; then
        echo "DISK_DEV not set"
        return 1
    fi
    if [ ! -b "$DISK_DEV" ]; then
        echo "DISK_DEV not a block device: $DISK_DEV"
        return 1
    fi
    is_valid_url "$UBUNTU_RASPI_IMAGE_URL"
    if [ $? -ne 0 ]; then
        echo "URL not found: $UBUNTU_RASPI_IMAGE_URL"
        return 1
    fi
    echo "UBUNTU_RASPI_IMAGE_URL is valid"
    echo ""
    echo "---------------------------------------------------------------------------"
    echo "Confirm using following device: $DISK_DEV"
    echo "All data on $DISK_DEV will be lost"
    echo "---------------------------------------------------------------------------"
    confirm_target_disk $DISK_DEV || return 1
    wget -q -nd -O - "$UBUNTU_RASPI_IMAGE_URL" | xzcat - | sudo dd of=$DISK_DEV bs=1M status=progress oflag=direct iflag=fullblock
    if [ $? -ne 0 ]; then
        echo "Download and write to $DISK_DEV failed"
        echo "You will need to rewrite the image"
        return 1
    fi
    # Signal kernel to see new partitions
    sudo partprobe
}

function mount_partitions {
    # ASSUMES check_target_dev was already called and was successful

    # $MOUNT_BOOT_DIR
    # Nothing is mounted
    is_mounted $MOUNT_BOOT_DIR
    if [ $? -eq 0 ]; then
        echo "Already a mount point: $MOUNT_BOOT_DIR"
        return 1
    fi
    mkdir -p $MOUNT_BOOT_DIR
    # Dir if present must be empty
    dir_is_empty $MOUNT_BOOT_DIR
    if [ $? -ne 0 ]; then
        echo "Not empty: $MOUNT_BOOT_DIR"
        return 1
    fi
    # Mount
    mount ${DISK_DEV}$DISK_DEV_BOOT_PARTNUM $MOUNT_BOOT_DIR
    if [ $? -ne 0 ]; then
       return 1
    fi
    MOUNTED_DIRS_TO_UNMOUNT="$MOUNTED_DIRS_TO_UNMOUNT $MOUNT_BOOT_DIR"

    # $MOUNT_ROOT_DIR
    # Nothing is mounted
    is_mounted $MOUNT_ROOT_DIR
    if [ $? -eq 0 ]; then
        echo "Already a mount point: $MOUNT_ROOT_DIR"
        return 1
    fi
    mkdir -p $MOUNT_ROOT_DIR
    # Dir if present must be empty
    dir_is_empty $MOUNT_ROOT_DIR
    if [ $? -ne 0 ]; then
        echo "Not empty: $MOUNT_ROOT_DIR"
        return 1
    fi
    # Mount
    mount ${DISK_DEV}$DISK_DEV_ROOT_PARTNUM $MOUNT_ROOT_DIR
    if [ $? -ne 0 ]; then
       return 1
    fi
    MOUNTED_DIRS_TO_UNMOUNT="$MOUNTED_DIRS_TO_UNMOUNT $MOUNT_ROOT_DIR"
}

function replace_boot_firmware_config {
    echo "Replacing firware and config under $MOUNT_BOOT_DIR"
    is_mounted $MOUNT_BOOT_DIR
    if [ $? -ne 0 ]; then
        echo "Not a mount point: $MOUNT_BOOT_DIR"
        return 1
    fi
    # Check firmware image URLs
    # Only FIRST element in FIRMWARE_NAMES is used
    local firmware_name=$(echo "$FIRMWARE_NAMES" | awk '{print $1}')
    echo "Checking firmware URLs:"
    errors=0
    echo -n "    $firmware_name : "
    is_valid_url "$FIRMWARE_URL_PREFIX/${firmware_name}.${DEB_FW_TS}.orig.tar.gz"
    [ $? -eq 0 ] && echo "OK" || (echo "Not found"; errors=1)
    if [ $errors -ne 0 ]; then
        return $errors
    fi

    # stash config.txt
    mkdir -p $MOUNT_BOOT_DIR/.bak
    mv $MOUNT_BOOT_DIR/config.txt $MOUNT_BOOT_DIR/.bak/
    # Remove rest under MOUNT_BOOT_DIR
    rm -rf $MOUNT_BOOT_DIR/*

    # Extract boot from firmware
    echo "Downloading firmware $firmware_name and extracting boot dir"
    local oldpwd=$(readlink -e $(pwd))
    cd $MOUNT_BOOT_DIR
    wget -nd --quiet -O - "$FIRMWARE_URL_PREFIX/${firmware_name}.${DEB_FW_TS}.orig.tar.gz" | tar zxf - $FIRMWARE_EXTRACT_DIR/boot
    if [ $? -ne 0 ]; then
        echo "Download, extract of boot dir from firmware failed"
        return 1
    fi
    if [ ! -d "$FIRMWARE_EXTRACT_DIR" ]; then
        echo "Extracted dir name was wrong"
        cd "$oldpwd"
        return 1
    fi
    mv $FIRMWARE_EXTRACT_DIR/boot/* .
    rmdir $FIRMWARE_EXTRACT_DIR/boot/
    rmdir $FIRMWARE_EXTRACT_DIR
    # Restore config.txt
    mv .bak/config.txt .
    rmdir .bak
    # Add lines to config.txt
    cat $TOP_DIR/ubuntu_prep/config/config.append >> config.txt

    cd "$oldpwd"
}

function update_root_partition {
    echo "Updating root partition"
    errors=0
    is_mounted $MOUNT_ROOT_DIR
    if [ $? -ne 0 ]; then
        echo "Not a mount point: $MOUNT_ROOT_DIR"
        errors=1
    fi
    
    for v in ROOT_PART_TOP_DIR ROOT_PART_DEB_DIR ROOT_PART_PKGS_DIR ROOT_PART_ASTERISK_BUILD_DIR
    do
        if [ -z "${!v}" ]; then
            echo "${v}: unset"
            errors=1
        fi
    done

    # Check DEB URLs
    echo "Checking DEB URLs"
    for p in $DEB_NAMES
    do
        echo -n "    $p : "
        is_valid_url "$DEB_URL_PREFIX/${p}.${DEB_FW_TS}-1_armhf.deb"
        [ $? -eq 0 ] && echo "OK" || (echo "Not found"; errors=1)
    done
    if [ $errors -ne 0 ]; then
        return $errors
    fi

    # Make required dirs
    for v in ROOT_PART_TOP_DIR ROOT_PART_DEB_DIR ROOT_PART_PKGS_DIR ROOT_PART_ASTERISK_BUILD_DIR
    do
        mkdir -p ${MOUNT_ROOT_DIR}//${!v}
    done
    local top_dir=${MOUNT_ROOT_DIR}/$ROOT_PART_TOP_DIR
    # Copy scripts to root dir
    cp -r ${TOP_DIR}/. $top_dir/.

    # Download debs
    local oldpwd=$(readlink -e $(pwd))
    local target_dir=${MOUNT_ROOT_DIR}/${ROOT_PART_DEB_DIR}
    cd $target_dir
    echo "Deleting existing debs"
    \rm -f *.deb
    echo "Downloading DEBS..."
    for p in $DEB_NAMES
    do
        echo -n "    $p ... "
        wget -nd --quiet "$DEB_URL_PREFIX/${p}.${DEB_FW_TS}-1_armhf.deb"
        if [ $? -eq 0 ]; then
            echo "ok"
        else
            echo "Error downloading $p"
            errors=1
        fi
    done

    # Update /etc/hostname
    if [ -n "$ASTERISK_HOSTNAME" ]; then
        echo "Updating /etc/hostname"
        sed -i -e "s/^.*$/$ASTERISK_HOSTNAME/" $MOUNT_ROOT_DIR/etc/hostname
    else
        echo "ASTERISK_HOSTNAME not set. Will not update /etc/hostname"
    fi
    local curr_hostname=$(cat $MOUNT_ROOT_DIR/etc/hostname)
    echo "Hostname will be: $curr_hostname"
    # Update /etc/hosts - even if ASTERISK_HOSTNAME is not set
    echo "Updating /etc/hosts"
    sed -i -e "s/localhost$/localhost $curr_hostname/" $MOUNT_ROOT_DIR/etc/hosts

    # Restore SSH host keys to /etc/ssh
    if [ -d ${top_dir}/ubuntu_prep/ssh/etc_ssh ]; then
        echo "Restoring host SSH keys"
        \cp -f ${top_dir}/ubuntu_prep/ssh/etc_ssh/* $MOUNT_ROOT_DIR/etc/ssh/
        chown root.root $MOUNT_ROOT_DIR/etc/ssh/*_key $MOUNT_ROOT_DIR/etc/ssh/*_key.pub
        chmod go= $MOUNT_ROOT_DIR/etc/ssh/*_key
    fi
    # Restore authorized keys under /root/.ssh
    # Can't restore to ~ubuntu/.ssh because /home/ubuntu won't exist yet!
    if [ -f ${top_dir}/ubuntu_prep/ssh/.ssh/authorized_keys ]; then
        echo "Restoring authorized keys"
        mkdir -p $MOUNT_ROOT_DIR/root/.ssh
        \cp -f ${top_dir}/ubuntu_prep/ssh/.ssh/authorized_keys $MOUNT_ROOT_DIR/root/.ssh
        chown -R root.root $MOUNT_ROOT_DIR/root/.ssh
        chmod -R go= $MOUNT_ROOT_DIR/root/.ssh
    fi

    cd $oldpwd
}

echo "Checking for list of required directories"
check_reqd_dirs $REQUIRED_DIRS
if [ $? -ne 0 ]; then
    if [ -z "$BASH_SOURCE" ]; then
        exit 1
    fi
fi   
