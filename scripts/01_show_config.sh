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

show_config
