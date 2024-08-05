#!/bin/sh
#
#  Part of https://github.com/jaclu/AOK-Filesystem-Tools
#
#  License: MIT
#
#  Copyright (c) 2023: Jacob.Lundqvist@gmail.com
#
#  select_distro.sh
#
#  Setup Distro choice
#

select_distro() {
    text="
This is AOK-Filesystem-Tools version: $AOK_VERSION

Alpine is the regular AOK FS, fully stable.

Debian is version 10 (Buster). It was end of lifed 2022-07-18 and is
thus now unmaintained except for security updates.
It should be fine for testing Debian with the AOK FS extensions under iSH-AOK.

Select distro:
 1 - Alpine $ALPINE_VERSION
 2 - Debian 10
"
    echo "$text"
    read -r selection
    echo
    case "$selection" in

    1)
        echo "Alpine selected"
        echo
        msg_1 "running $setup_alpine_scr"
        rm -f "$f_destfs_select_hint"
        "$setup_alpine_scr"
        ;;

    2)
        echo "Debian selected"
        /opt/AOK/choose_distro/install_debian.sh
        ;;

    # 3)
    #     echo "Devuan selected"
    #     /opt/AOK/choose_distro/install_devuan.sh
    #     ;;

    *)
        echo "*****   Invalid selection   *****"
        sleep 1
        select_distro
        ;;

    esac
}

#===============================================================
#
#   Main
#
#===============================================================

#
#  Mostly needed in case nav-keys.sh or some other config task
#  would be run before the first re-boot
#
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/usr/sbin:/bin:/usr/bin

tcd_start="$(date +%s)"

hide_run_as_root=1 . /opt/AOK/tools/run_as_root.sh
[ -z "$d_aok_etc" ] && . /opt/AOK/tools/utils.sh

manual_runbg

#  shellcheck disable=SC2009
if ! this_fs_is_chrooted && ! ps ax | grep -v grep | grep -qw cat; then
    cat /dev/location >/dev/null &
    msg_1 "iSH now able to run in the background"
fi

select_distro

duration="$(($(date +%s) - tcd_start))"
display_time_elapsed "$duration" "Choose Distro"
