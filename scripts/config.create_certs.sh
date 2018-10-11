# ------------------------------------------------------------------------
# Config for create_certs.sh
# ------------------------------------------------------------------------
# DEST_DIR will be created if it does not exist
# DEST_DIR/keys should NOT exist
DEST_DIR=/etc/asterisk

# ------------------------------------------------------------------------
# CA details
# ------------------------------------------------------------------------
# CN for CA - defaults to hostname if not set
CA_CN=
# Org for CA - defaults to hostname if not set
CA_ORG=
# CA RSA key size in bits - defaults to 4096 if not set
CA_RSA_KEY_BITS=4096
# CA Validity defaults to 3650 (10 years) if not set
CA_VALIDITY_DAYS=3650
# This was the default (des3 == triple-DES)
# CA_ENC_TYPE=des3
CA_ENC_TYPE=aes256

# ------------------------------------------------------------------------
# Asterisk host cert details
# ------------------------------------------------------------------------
# CN for Asterisk - defaults to hostname if not set
AST_CN=
# Org for Asterisk - defaults to hostname if not set
AST_ORG=
# Asterisk RSA key size in bits - defaults to 4096 if not set
AST_RSA_KEY_BITS=4096
# Asterisk Validity defaults to 3650 (10 years) if not set
AST_VALIDITY_DAYS=3650
# This was the default (des3 == triple-DES)
# AST_ENC_TYPE=des3
AST_ENC_TYPE=aes256


# ------------------------------------------------------------------------
# Do not need to change abything below this
# ------------------------------------------------------------------------
# Set defaults 
HN=$(hostname)

CA_CN=${CA_CN:-$HN}
CA_ORG=${CA_ORG:-$HN}
CA_RSA_KEY_BITS=${CA_RSA_KEY_BITS:-4096}
CA_VALIDITY_DAYS=${CA_VALIDITY_DAYS:-3650}
CA_ENC_TYPE=${CA_ENC_TYPE:-aes256}

AST_CN=${AST_CN:-$HN}
AST_ORG=${AST_ORG:-$HN}
AST_RSA_KEY_BITS=${AST_RSA_KEY_BITS:-4096}
AST_VALIDITY_DAYS=${AST_VALIDITY_DAYS:-3650}

DEST_DIR=${DEST_DIR:-$PROG_DIR}
KEYS_DIR="${DEST_DIR}"/keys


echo "# ------------------------------------------------------------------------"
echo "# ${PROG_NAME} settings"
echo "# ------------------------------------------------------------------------"
for x in CA_CN CA_ORG CA_RSA_KEY_BITS CA_VALIDITY_DAYS CA_ENC_TYPE AST_CN AST_ORG AST_RSA_KEY_BITS AST_VALIDITY_DAYS DEST_DIR KEYS_DIR
do
	printf "%-20s : %s\n" "${x}"  "${!x}"
done

function check_dest_dir {
    if [ ! -d "$DEST_DIR" ]; then
    	mkdir -p "$DEST_DIR"
    	if [ $? -ne 0 ]; then
    		echo "DEST_DIR does not exist and could not be created: $DEST_DIR"
    		return 1
    	fi
    fi
    if [ -d "${KEYS_DIR}" ]; then
    	if [ $(ls -1A "${KEYS_DIR}" | wc -l) -ne 0 ]; then
    		echo "KEYS_DIR already exists and is not empty: ${KEYS_DIR}"
    		return 1
    	fi
    else
    	mkdir -p "${DEST_DIR}"/keys
    	if [ $? -ne 0 ]; then
    		echo "KEYS_DIR does not exist and could not be created: $KEYS_DIR"
    		return 1
    	fi
    fi
}

check_dest_dir || exit 1
