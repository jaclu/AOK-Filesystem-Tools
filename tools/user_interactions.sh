#!/bin/sh
# This is sourced. Fake bang-path to help editors and linters
#  shellcheck disable=SC2154
#
#  Part of https://github.com/jaclu/AOK-Filesystem-Tools
#
#  License: MIT
#
#  Copyright (c) 2023: Jacob.Lundqvist@gmail.com
#
#  Handling user interactions during deploy of FS
#   - Asking for TZ
#   - Should any external resource be mounted
#
#  This expects to be sourced AFTER utils.sh is sourced, it relies on
#  tools resources to be available!
#

this_fs_is_mounted() {
    mount | grep -wq "$1"
}

should_it_be_mounted() {
    d_mount_path="$1"
    msg_2 "should_it_be_mounted($d_mount_path)"

    if thisfs_is_mounted "$d_mount_path"; then
        msg_3 "was already mounted, returning"
        return
    fi

    # _sibm_dlg_app="dialog"
    _sibm_dlg_app="whiptail"

    if [ -z "$(command -v "$_sibm_dlg_app")" ]; then
        sibm_dependency="$_sibm_dlg_app"
        msg_3 "Installing dependency: $sibm_dependency"

        if [ "$sibm_dependency" = "whiptail" ] && fs_is_alpine; then
            # whiptail is in package newt in Alpine
            sibm_dependency="newt"
        fi
        if fs_is_alpine; then
            apk add "$sibm_dependency"
        elif [ -f "$f_debian_version" ]; then
            apt install "$sibm_dependency"
        else
            error_msg "Unrecognized distro, aborting"
        fi
        unset sibm_dependency
    fi

    _sibm_text="Do you want to mount $d_mount_path now?"
    # --topleft \
    "$_sibm_dlg_app" \
        --title "Mount $d_mount_path" \
        --yesno "$_sibm_text" 0 0

    _sibm_exitstatus=$?

    if [ "$_sibm_exitstatus" -eq 0 ]; then
        mount -t ios x "$d_mount_path"
        msg_1 "$d_mount_path has been mounted!"
    else
        msg_3 "mount rejected"
    fi

    unset _sibm_dlg_app
    unset _sibm_text
    unset _sibm_exitstatus
    # msg_3 "should_it_be_mounted()  done"
}

check_defined_mounts() {
    msg_2 "check_defined_mounts($IOS_MOUNTS)"

    if ! this_is_ish; then
        msg_3 "This is not iSH, skipping iOS mount check"
        return
    fi

    # shellcheck disable=SC2086 # this should be expanded
    set -- $IOS_MOUNTS
    for d_mount_path in "$@"; do
	this_fs_is_mounted "$d_mount_path" && continue
	should_it_be_mounted "$d_mount_path"
    done
}

user_interactions() {
    msg_2 "user_interactions()"

    check_defined_mounts

    if [ -z "$AOK_TIMEZONE" ]; then
        msg_1 "Timezone selection"
        /opt/AOK/common_AOK/usr_local_bin/set-timezone
    fi
    # msg_3 "user_interactions()  - done"
}

#===============================================================
#
#   Main
#
#===============================================================

_this_script="user_interactions.sh"

#
#  Argh if this is sourcecd from a login script, like when used by a
#  script masking as /etc/profile $0 will be something like -ash
#  So here the usual basename $0 would fail in such cases
#
_scr_name="$0"
if [ "${_scr_name#-}" != "$_scr_name" ]; then
    _scr_name="${_scr_name#-}"
fi

if [ "$(basename "$_scr_name")" = "$_this_script" ]; then
    echo
    echo "*****  USAGE ERROR  *****"
    echo
    echo "$_this_script can't be run, it is a support module"
    echo "expected to be sourced from other apps"
    echo
    exit 1
fi

if [ -z "$AOK_VERSION" ]; then
    echo
    echo "*****  USAGE ERROR  *****"
    echo
    echo "$_this_script must be sourced after utils.sh is sourced."
    echo
    exit 1
fi

unset _this_script
unset _scr_name
