#!/bin/bash
REQD_PKGS="parted util-linux curl wget gawk coreutils"


$(dirname $0)/pkgs_missing_from.sh $REQD_PKGS
