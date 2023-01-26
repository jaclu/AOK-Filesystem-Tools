#!/bin/sh
#
#  Part of https://github.com/emkey1/AOK-Filesystem-Tools
#
#  License: MIT
#
#  Copyright (c) 2023: Jacob.Lundqvist@gmail.com
#
#  Prepares the Alpine image to show Distribution selection dialog
#

if [ ! -d "/opt/AOK" ]; then
    echo "ERROR: This is not an AOK File System!"
    echo
    exit 1
fi

#
#  Since this is run as /etc/profile during deploy, and this wait is
#  needed for /etc/profile (see Alpine/etc/profile for details)
#  we also put it here
#
sleep 1

# shellcheck disable=SC1091
. /opt/AOK/tools/utils.sh

msg_title "select_distro_prepare.sh  Prep for distro select"

#
#  Needed in order to find dialog/newt in case they have been updated
#
msg_3 "apk update & upgrade"
apk update && apk upgrade

msg_3 "Installing newt (whiptail) & wget (needed for Debian download)"
apk add newt wget

# shellcheck disable=SC2154
bldstat_set "$status_select_distro_prepared"

# shellcheck disable=SC2154
select_profile "$setup_select_distro"

# shellcheck disable=SC2154
if is_chrooted; then
    echo "This is chrooted, doesn't make sense to select Distro"
    exit
fi
