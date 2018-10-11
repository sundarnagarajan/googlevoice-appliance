#!/bin/bash

if [ -n "$BASH_SOURCE" ]; then
    PROG_PATH=${PROG_PATH:-$(readlink -e $BASH_SOURCE)}
else
    PROG_PATH=${PROG_PATH:-$(readlink -e $0)}
fi
PROG_DIR=${PROG_DIR:-$(dirname ${PROG_PATH})}
PROG_NAME=${PROG_NAME:-$(basename ${PROG_PATH})}
SCRIPT_DIR="${PROG_DIR}"

function ensure_arm_arch {
    local arch=$(uname -m)
    if [ "$arch" != "armv7l" ]; then
        echo "Only run this script on a raspberry Pi!"
        return 1
    fi
}

ensure_arm_arch || exit 1

# Source functions
if [ -f "${SCRIPT_DIR}/functions.sh" ]; then
    . "${SCRIPT_DIR}/functions.sh"
    if [ $? -ne 0 ]; then
        echo "Error sourcing functions: ${SCRIPT_DIR}/functions.sh"
        exit 1
    fi
else
    echo "functions not found: ${SCRIPT_DIR}/functions.sh"
    exit 1
fi

function asterisk_check_reqd_dirs {
    # Params: list of required dirs
    check_reqd_dirs || return 1
    errors=0
    for v in ROOT_PART_TOP_DIR ROOT_PART_DEB_DIR ROOT_PART_PKGS_DIR ROOT_PART_ASTERISK_BUILD_DIR
    do
        echo -n "${v}: ... "
        if [ -z "${!v}" ]; then
            echo "unset"
            errors=1
        else
            if [ ! -e "${!v}" ]; then
                echo "missing"
                errors=1
            elif [ ! -d "${!v}" ]; then
                echo "Not a directory"
                errors=1
            fi
        fi
        echo "ok"
    done
    return $errors
}

function installed_pkgs_sorted {
    # Outputs on stdout
    export LC_ALL=C
    dpkg -l | grep '^ii' | awk '{print $2}' | LC_ALL=C sort | uniq
}

function pkg_is_installed {
    dpkg -l | grep '^ii' | awk '{print $2}' | fgrep -qx $1
}

function install_if_missing {
    # Accepts LIST of params: package names
    local missing=""
    for i in $@
    do
        pkg_is_installed $i
        if [ $? -ne 0 ]; then
            missing="$missing $i"
        fi
    done
    local install_cmd="apt install -y $missing"
    $install_cmd
    return $?
}

function update_raspi_packages {
    asterisk_check_reqd_dirs || return 1
    # Check DEBs are all available
    errors=0
    echo "Checking DEBS:"

    for p in $DEB_NAMES
    do
        echo -n "    $p ... "
        if [ -f ${ROOT_PART_DEB_DIR}/${p}.${DEB_FW_TS}-1_armhf.deb ]; then
            echo "ok"
        else
            echo "missing"
            errors=1
        fi
    done
    if [ $errors -ne 0 ]; then
        return $errors
    fi

    # Save initial list of installed packages
    installed_pkgs_sorted > ${ROOT_PART_PKGS_DIR}/${PKGLIST_00_UBUNTU}
    # Remove raspi2 packages
    apt-get purge -y $(installed_pkgs_sorted | grep raspi2)
    # NEED to install device-tree-compiler BEFORE installing DEBS
    apt-get update
    install_if_missing device-tree-compiler

    # Install downloaded DEBs
    local deb_file_list=""
    for p in $DEB_NAMES
    do
        echo -n "    $p ... "
        deb_file_list="$deb_file_list ${ROOT_PART_DEB_DIR}/${p}.${DEB_FW_TS}-1_armhf.deb"
    done
    if [ -n "$deb_file_list" ]; then
        dpkg -i $deb_file_list
    else
        echo "No DEB files to install"
    fi

    echo "---------------------------------------------------------------------------"    
    echo "Configuring timezone and locales - you will need to select"
    echo "Press RETURN to continue"
    echo "---------------------------------------------------------------------------" 
    read a
    dpkg-reconfigure tzdata
    dpkg-reconfigure locales

    # Disable services we do not need
    if [ -n "$ASTERISK_SEVICES_TO_DISABLE" ]; then
        systemctl disable $ASTERISK_SEVICES_TO_DISABLE
    fi
    if [ -n "$ASTERISK_BUILD_PKGS_MINIMAL" ]; then
        echo "Installing minimal build-related packages"
        install_if_missing $ASTERISK_BUILD_PKGS_MINIMAL
    fi
    # Save list of installed packages after raspi updates
    installed_pkgs_sorted > ${ROOT_PART_PKGS_DIR}/${PKGLIST_01_RASPI_UPDATES}

    echo ""
    echo ""
    echo "---------------------------------------------------------------------------"    
    echo "You need to reboot the Raspberry Pi now"
    echo "---------------------------------------------------------------------------"    
    echo ""
    echo ""
}

function calc_asterisk_depends {
    # Fix the package lists IN CASE sort is mis-behaving
    export LC_ALL=C
    for f in $PKGLIST_02_ASTERISK_PREREQ $PKGLIST_01_RASPI_UPDATES
    do
        LC_ALL=C sort < ${ROOT_PART_PKGS_DIR}/$f | uniq > /tmp/pkglist
        rm -f ${ROOT_PART_PKGS_DIR}/$f
        mv /tmp/pkglist ${ROOT_PART_PKGS_DIR}/$f
    done

    local dev_pkgs_to_keep="autotools-dev binutils-dev dpkg-dev libraspberrypi-dev libsensors4-dev manpages-dev python-dev python2.7-dev"
    echo "$dev_pkgs_to_keep" | tr ' ' '\n' | LC_ALL=C sort | uniq > ${ROOT_PART_PKGS_DIR}/$PKGLIST_04_ASTERISK_PREREQ_DEV_KEEP
    join -v1 ${ROOT_PART_PKGS_DIR}/$PKGLIST_02_ASTERISK_PREREQ ${ROOT_PART_PKGS_DIR}/$PKGLIST_01_RASPI_UPDATES | grep -- '-dev$' | sed -e 's/:armhf$//g' > ${ROOT_PART_PKGS_DIR}/$PKGLIST_05_ASTERISK_PREREQ_DEV_ALL
    join -v1 ${ROOT_PART_PKGS_DIR}/$PKGLIST_05_ASTERISK_PREREQ_DEV_ALL ${ROOT_PART_PKGS_DIR}/$PKGLIST_04_ASTERISK_PREREQ_DEV_KEEP | sed -e 's/:armhf$//g' > ${ROOT_PART_PKGS_DIR}/$PKGLIST_06_ASTERISK_PREREQ_DEV_DEL
    join -v1 ${ROOT_PART_PKGS_DIR}/$PKGLIST_02_ASTERISK_PREREQ ${ROOT_PART_PKGS_DIR}/$PKGLIST_01_RASPI_UPDATES | sed -e 's/:armhf$//g' | LC_ALL=C sort | uniq > /tmp/pkglist
    # Avoid putting libspeex* in depends since it conflicts with asterisk >13.x
    join -v1 /tmp/pkglist ${ROOT_PART_PKGS_DIR}/$PKGLIST_06_ASTERISK_PREREQ_DEV_DEL | sed -e 's/:armhf$//g' | grep -v '^libspeex' > ${ROOT_PART_PKGS_DIR}/$PKGLIST_07_ASTERISK_DEB_DEPENDS

    rm -f /tmp/pkglist
}


function install_asterisk_prereqs {
    # Based on: https://community.freepbx.org/t/how-to-guide-for-google-voice-with-freepbx-14-asterisk-gvsip-ubuntu-18-04/50933

    asterisk_check_reqd_dirs || return 1
    install_if_missing software-properties-common && sudo add-apt-repository -y ppa:ondrej/php && true || return 1
    apt update && apt upgrade -y && apt dist-upgrade -y
    install_if_missing git curl apt-transport-https net-tools

    # Install ALL the pre-reqs (including -dev packages)
    wget -nd -O - 'https://raw.githubusercontent.com/naf419/asterisk/15/contrib/scripts/install_prereq' > /tmp/install_prereq
    if [ $? -ne 0 ]; then
        return 1
    fi
    yes | sh -c /tmp/install_prereq install
    if [ $? -ne 0 ]; then
        echo "install_prereq failed"
        return 1
    fi

    # Save list of installed packages after installing asterisk prereqs
    installed_pkgs_sorted > ${ROOT_PART_PKGS_DIR}/${PKGLIST_02_ASTERISK_PREREQ}

    echo ""
    echo ""
    echo "---------------------------------------------------------------------------"    
    echo "You need to reboot the Raspberry Pi now"
    echo "---------------------------------------------------------------------------"    
    echo ""
    echo ""
}

function install_asterisk_from_deb {
    if [ ! -d ${ROOT_PART_TOP_DIR}/asterisk_deb ]; then
        echo "Directory not found: ${ROOT_PART_TOP_DIR}/asterisk_deb"
        echo "Cannot use pre-built asterisk DEB"
        return 1
    fi
    if [ $(ls -1 ${ROOT_PART_TOP_DIR}/asterisk_deb/*.deb | wc -l) -lt 1 ]; then
        echo "No DEB files found in ${ROOT_PART_TOP_DIR}/asterisk_deb"
        echo "Cannot use pre-built asterisk DEB"
        return 1
    fi
    # Check that at least one DEB file is for package 'asterisk'
    local deb_found=0
    for deb in $(ls -1 ${ROOT_PART_TOP_DIR}/asterisk_deb/*.deb)
    do
        dpkg-deb --showformat='${Package}' -W $deb | fgrep -qx asterisk
        if [ $? -eq 0 ]; then
            deb_found=1
            break
        fi
    done
    if [ $deb_found -eq 0 ]; then
        echo "No asterisk DEB found"
        echo "Cannot use pre-built asterisk DEB"
        return 1
    fi

    asterisk_check_reqd_dirs || return 1
    install_if_missing software-properties-common && sudo add-apt-repository -y ppa:ondrej/php && true || return 1
    apt update && apt upgrade -y && apt dist-upgrade -y

    # Install DEB - will produce errors because of dependencies
    # Needs subsequent apt-get -f install to install dependencies

    # libspeex1 in xenial depends on asterisk <= 1:13 !
    # apt-get -y remove libspeex1

    dpkg -i ${ROOT_PART_TOP_DIR}/asterisk_deb/*.deb 1>/dev/null 2>&1
    local ret=$?
    if [ $ret -ne 0 ]; then
        echo "--------------------------------------------------------------------------"
        echo "dpkg returned $ret. Will run 'apt-get -f install' to install dependencies"
        echo "--------------------------------------------------------------------------"
        apt-get -y -f install
        ret=$?
        if [ $ret -ne 0 ]; then
            echo "'apt-get -f install' returned ${ret}. Install of asterisk deb failed"
            return 1
        fi
    fi
    # DEB install was successful - hold asterisk package so that repo asterisk will
    # never update and overwrite (GV will no longer work!)
    echo "--------------------------------------------------------------------------"
    echo "Marking package asterisk as held"
    echo "'apt update' and 'apt dist-upgrade' will not update asterisk"
    echo "Use 'apt-mark showhold' to see"
    echo "Use 'apt-mark unhold asterisk' to disable hold"
    echo "--------------------------------------------------------------------------"
    apt-mark hold asterisk
    # DEB install was successful - remove -dev packages
    # apt-get remove $(dpkg -l | grep '^ii' | awk '{print $2}' | grep -- '-dev$' | egrep -v '^(autotools-dev|binutils-dev|dpkg-dev|libraspberrypi-dev|libsensors4-dev|python-dev|python2.7-dev|manpages-dev)$')
}

function build_asterisk {
    # Based on: https://community.freepbx.org/t/how-to-guide-for-google-voice-with-freepbx-14-asterisk-gvsip-ubuntu-18-04/50933

    ./configure --with-pjproject-bundled --with-jansson-bundled
    make menuselect.makeopts
    menuselect/menuselect --enable format_mp3 --enable app_macro --enable CORE-SOUNDS-EN-WAV --enable CORE-SOUNDS-EN-ULAW menuselect.makeopts
    make
    mkdir -p /etc/asterisk
    cp configs/samples/smdi.conf.sample /etc/asterisk/smdi.conf
}

function build_asterisk_deb {
    asterisk_check_reqd_dirs || return 1
    local oldpwd=$(readlink -e $(pwd))
    local deb_build_dir=${ROOT_PART_ASTERISK_BUILD_DIR}/asterisk 
    if [ ! -d "$deb_build_dir" ]; then
        echo "Directory not found: $deb_build_dir"
        return 1
    fi
    cd "$deb_build_dir"

    # We install checkinstall ONLY if and when build_asterisk_deb is called
    local checkinstall_pkg=checkinstall
    dpkg -l $checkinstall_pkg 2>/dev/null | grep '^ii' | awk '{print $2}' | fgrep -qx $checkinstall_pkg
    if [ $? -ne 0 ]; then
        apt install -y checkinstall || return 1
    fi

    # grep '^PACKAGES_DEBIAN=' contrib/scripts/install_prereq > get_prereq_packages.sh
    # echo "echo \$PACKAGES_DEBIAN" >> get_prereq_packages.sh
    echo "make install" > make_deb_install_steps.sh
    echo "make config" >> make_deb_install_steps.sh

    calc_asterisk_depends

    local PREREQ_PKGS="$(dpkg -l $(cat ${ROOT_PART_PKGS_DIR}/$PKGLIST_07_ASTERISK_DEB_DEPENDS ) 2>/dev/null | sed -e '1,5d' | awk '{printf("%s \\(\\>=%s\\),", $2, $3)}' | sed -e 's/,$//')"

    # local PREREQ_PKGS=$(dpkg -l $((for p2 in $(for p in $(echo $(sh ./get_prereq_packages.sh ) | sed -e 's/[ ][ ]*/\n/g' | grep  -- '-dev$' ); do p1=$(echo $p | sed -e 's/-dev$//'); echo $p1; done); do dpkg -l $p2 2>/dev/null | grep '^ii' | awk '{print $2}' ; done ; echo $(sh ./get_prereq_packages.sh ) | sed -e 's/[ ][ ]*/\n/g' | grep -v -- '-dev$') | sort | uniq | tr '\n' ' ' | sed -e 's/:armhf//g') | sed -e '1,5d' | awk '{printf("%s (>=%s), ", $2, $3)}' | sed -e 's/:armhf//g' | sed -e 's/, $//' | sed -e 's/, /,/g' -e 's/(/\\(/g' -e 's/)/\\)/g' -e 's/>/\\>/g')
    # PREREQ_PKGS="${PREREQ_PKGS},apt-transport-https,net-tools,mpg123,sox,unixodbc,ffmpeg,lame,mailutils"

    checkinstall --fstrans=yes --install=no --pkgversion="$ASTERISK_DEB_PKG_VERSION" --pkgsource="$ASTERISK_DEB_PKG_SOURCE" --requires="$PREREQ_PKGS" -y sh ./make_deb_install_steps.sh
    if [ $? -eq 0 ]; then
        mkdir -p ${TOP_DIR}/asterisk_deb
        \cp -f *.deb  ${TOP_DIR}/asterisk_deb/
    else
        return 1
    fi
    rm -f make_deb_install_steps.sh
}


function install_asterisk_from_source {
    make install || return 1
    make config || return 1
    build_asterisk_deb    # Ignore non-zero return code
}

function postinstall_asterisk {
    ldconfig
    update-rc.d -f asterisk remove

    # Set initial config and permissions
    mkdir -p /etc/asterisk
    touch /etc/asterisk/{modules,ari,statsd}.conf

    useradd -m asterisk
    mkdir -p /var/log/asterisk/cdr-csv /var/lib/asterisk/firmware/iax /var/lib/asterisk/keys /var/lib/asterisk/sounds
    chown -R asterisk. /var/{lib,log,spool,run}/asterisk
    chown -R asterisk. /etc/asterisk /usr/lib/asterisk

    # Do NOT install basic samples - these OVERRIDE standard config
    # make samples
    # Do NOT create basic PBX - start with STANDARD config and work from there
    # make basic-pbx
}

function asterisk_disable_speek {
    local speex_pkg=libspeex1
    dpkg -l $speex_pkg 2>/dev/null | grep '^ii' | awk '{print $2}' | fgrep -qx $speex_pkg
    if [ $? -eq 0 ]; then
        echo "$speex_pkg installed. No need to disable speex"
        return
    fi
    if [ -f /etc/asterisk/modules_noload_local.conf ]; then
        MOD_FILE=/etc/asterisk/modules_noload_local.conf
    else
        MOD_FILE=/etc/asterisk/modules.conf
    fi
    echo -e ";\n; Disable func_speex.so and codec_speex.so because\n; because we do not install libspeex1\n; because it depends on asterisk<=1:13\n;" >> $MOD_FILE
    for m in func_speex.so codec_speex.so
    do
        echo "noload = $m" >> $MOD_FILE
    done
}

function postinstall_generic {
    # Restore /etc/asterisk if present
    if [ -d ${TOP_DIR}/asterisk_config ]; then
        echo "Restoring asterisk config"
        \cp -rf ${TOP_DIR}/asterisk_config/. /etc/asterisk/.
        chown -R asterisk.asterisk /etc/asterisk/*
        chmod go= /etc/asterisk/manager.conf /etc/asterisk/acl.conf
    fi

    # Disable func_speex.so and codec_speex.so if libspeex1 is not installed
    asterisk_disable_speek

    # Generate keys if not present
    if [ -x ${PROG_DIR}/create_certs.sh ]; then
        echo "Generating asterisk keys if required"
        ${PROG_DIR}/create_certs.sh
    fi

    # Restart asterisk
    systemctl stop asterisk
    systemctl start asterisk
    systemctl --no-pager status asterisk
}

function build_install_asterisk {
    asterisk_check_reqd_dirs || return 1
    local oldpwd=$(readlink -e $(pwd))

    install_asterisk_from_deb
    if [ $? -ne 0 ]; then
        echo "--------------------------------------------------------------------------"
        echo "Could not install asterisk from DEB - will build, install from source"
        echo "--------------------------------------------------------------------------"

        # We avoid Apache2, all MySQL-related pkgs, PHP-related PKGS, mongodb, fail2ban, nodejs and freepbx
        install_if_missing git mpg123 sox unixodbc ffmpeg lame mailutils

        # Clear asterisk build dir
        echo "Clearing asterisk build dir: $ROOT_PART_ASTERISK_BUILD_DIR"
        \rm -rf $ROOT_PART_ASTERISK_BUILD_DIR
        mkdir -p $ROOT_PART_ASTERISK_BUILD_DIR
        local oldpwd=$(readlink -e $(pwd))
        cd ${ROOT_PART_ASTERISK_BUILD_DIR}
        git clone https://github.com/naf419/asterisk.git --branch gvsip
        cd asterisk
        sed -i 's/MAINLINE_BRANCH=.*/MAINLINE_BRANCH=15/' build_tools/make_version
        yes | contrib/scripts/get_mp3_source.sh
        cd ${ROOT_PART_ASTERISK_BUILD_DIR}/asterisk || return 1

        build_asterisk || return 1
        install_asterisk_from_source || return 1
    fi

    postinstall_asterisk
    postinstall_generic
    cd $oldpwd
}

function uninstall_asterisk {
    asterisk_check_reqd_dirs || return 1
    local oldpwd=$(readlink -e $(pwd))
    cd ${ROOT_PART_ASTERISK_BUILD_DIR}/asterisk || return 1
    make uninstall-all
    cd $oldpwd
}

function asterisk_remove_pkgs_installed {
    # Will uninstall asterisk, clear ${ROOT_PART_ASTERISK_BUILD_DIR} and remove
    # all packages installed as part of asterisk build

    uninstall_asterisk || return 1
    local pkgs_to_remove=$(join -v1 ${ROOT_PART_PKGS_DIR}/${PKGLIST_02_ASTERISK_PREREQ} ${ROOT_PART_PKGS_DIR}/${PKGLIST_01_RASPI_UPDATES})
    apt purge -y $pkgs_to_remove
}

