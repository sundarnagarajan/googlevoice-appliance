#!/bin/bash -e
# ------------------------------------------------------------------------
# Quick and dirty script to create asterisk certs
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
if [ -f "${SCRIPT_DIR}/config.${PROG_NAME}" ]; then
    . "${SCRIPT_DIR}/config.${PROG_NAME}"
    if [ $? -ne 0 ]; then
        echo "Error sourcing config: ${SCRIPT_DIR}/config.${PROG_NAME}"
        exit 1
    fi
else
    echo "config not found: ${SCRIPT_DIR}/config.${PROG_NAME}"
    exit 1
fi

CAKEY="$DEST_DIR"/keys/ca.key
CACERT="$DEST_DIR"/keys/ca.crt
CACFG="$DEST_DIR"/keys/ca.cfg
ASTKEY="$DEST_DIR"/keys/asterisk.key
ASTCERT="$DEST_DIR"/keys/asterisk.pem
ASTCFG="$DEST_DIR"/keys/asterisk.cfg
ASTCSR="$DEST_DIR"/keys/asterisk.csr

function generate_serial_number {
    ser_hex=$(echo -n "$(uuidgen -r)$(uuidgen -t)$(hexdump -n 32 -e '4/4 "%08X" 1 ""' /dev/urandom)" | sha512sum | cut -d' ' -f1 | sha1sum | cut -d' ' -f1 | tr [[:lower:]] [[:upper:]])
    echo "ibase=16; $ser_hex" | bc
}

function create_ca_config () {
    cat > "${CACFG}" << EOF
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
CN=${CA_CN}
O=${CA_ORG}

[ext]
basicConstraints=CA:TRUE"
EOF
}

function create_ast_config () {
    cat > "${ASTCFG}" << EOF
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
CN=${AST_CN}
O=${AST_ORG}
EOF
}

function create_ca_cert () {
    echo "Creating CA key ${CAKEY}"
    echo "$password" | openssl genrsa -passout stdin -${CA_ENC_TYPE} -out ${CAKEY} ${CA_RSA_KEY_BITS} > /dev/null
    if [ $? -ne 0 ];
    then
        echo "Failed"
        exit 1
    fi
    echo "Creating CA certificate ${CACERT}"
    echo "$password" | openssl req -passin stdin -new -config ${CACFG} -x509 -days ${CA_VALIDITY_DAYS} -key ${CAKEY} -out ${CACERT} > /dev/null
    if [ $? -ne 0 ]; then
        echo "Failed"
        exit 1
    fi
}


function create_ast_cert () {
    echo "Creating asterisk key: ${ASTKEY}"
    openssl genrsa -out ${ASTKEY} ${AST_RSA_KEY_BITS} > /dev/null
    if [ $? -ne 0 ];
    then
    	echo "Failed"
    	exit 1
    fi
    echo "Creating asterisk signing request ${ASTCSR}"
    openssl req -batch -new -config ${ASTCFG} -key ${ASTKEY} -out ${ASTCSR} > /dev/null
    if [ $? -ne 0 ];
    then
    	echo "Failed"
    	exit 1
    fi
    echo "Creating asterisk certificate ${ASTCERT}"
    local serial=$(generate_serial_number)
    echo "$password" | openssl x509 -passin stdin -req -days ${AST_VALIDITY_DAYS} -in ${ASTCSR} -CA ${CACERT} -CAkey ${CAKEY} -set_serial $serial -out ${ASTCERT} > /dev/null
    if [ $? -ne 0 ];
    then
    	echo "Failed"
    	exit 1
    fi
}


read -s -p "Enter CA key password: " password
echo ""
if [ -z "$password" ]; then
    exit 1
fi

create_ca_config
create_ast_config
create_ca_cert
${PROG_DIR}/show_cert.sh ${CACERT}
create_ast_config
create_ast_cert

${PROG_DIR}/show_cert.sh ${ASTCERT}

