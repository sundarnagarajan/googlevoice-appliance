#!/bin/bash
if [ -n "$BASH_SOURCE" ]; then
     PROG_PATH=${PROG_PATH:-$(readlink -e $BASH_SOURCE)}
else
    PROG_PATH=${PROG_PATH:-$(readlink -e $0)}
fi
PROG_DIR=${PROG_DIR:-$(dirname ${PROG_PATH})}
PROG_NAME=${PROG_NAME:-$(basename ${PROG_PATH})}
SCRIPT_DIR="${PROG_DIR}"

# Source functions
if [ -f "${SCRIPT_DIR}/asterisk_functions.sh" ]; then
    . "${SCRIPT_DIR}/asterisk_functions.sh"
    if [ $? -ne 0 ]; then
        echo "Error sourcing asterisk_functions: ${SCRIPT_DIR}/asterisk_functions.sh"
        exit 1
    fi
else
    echo "asterisk_functions not found: ${SCRIPT_DIR}/asterisk_functions.sh"
    exit 1
fi

start_time=$(date)

must_be_root || exit 1
uninstall_asterisk || exit 1

echo "Start time: $start_time"
echo "End time  : $(date)"
