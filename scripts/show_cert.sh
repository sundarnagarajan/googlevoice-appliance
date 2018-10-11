#!/bin/bash
if [ -z "$1" ]; then
    exit 0
fi
openssl x509 -noout -text -in "$1" | egrep '(Signature Algorithm:|Issuer:|Subject: |Not Before: |Not After : |Public-Key: |Serial Number: )'
