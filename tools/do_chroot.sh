#!/bin/sh
#
#  Copyright (c) 2022: Jacob.Lundqvist@gmail.com
#  License: MIT
#
#  Version: 1.3.0 2022-06-27
#
#

#  shellcheck disable=SC1007
CURRENT_D=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
FS_BUILD_D="$(dirname "$CURRENT_D")"

#
#  Ensure this is run in the intended location in case this was launched from
#  somewhere else, this to ensure BUILD_ENV can be found
#
cd "$FS_BUILD_D" || exit 1

# shellcheck disable=SC1091
. ./BUILD_ENV


prog_name=$(basename "$0")
CHROOT_TO="$BUILD_ROOT_D"


if [ "$(whoami)" != "root" ]; then
    echo "ERROR: This must be run as root or using sudo!"
    echo
    exit 1
fi



env_prepare() {
    echo "=====  Preparing the environment for chroot  ====="


    echo "---  Mounting system resources  ---"

    mount -t proc proc "$CHROOT_TO"/proc

    if [ -d "/proc/ish" ]; then
        echo "---  Setting up needed /dev items  ---"

        mknod "$CHROOT_TO"/dev/null c 1 3
        chmod 666 "$CHROOT_TO"/dev/null

        mknod "$CHROOT_TO"/dev/urandom c 1 9
        chmod 666 "$CHROOT_TO"/dev/urandom

        mknod "$CHROOT_TO"/dev/zero c 1 5
        chmod 666 "$CHROOT_TO"/dev/zero
    else
        # mount -o bind /tmp "$CHROOT_TO"/tmp
        mount -t sysfs sys "$CHROOT_TO"/sys
        mount -o bind /dev "$CHROOT_TO"/dev
    fi
}

env_cleanup() {
    echo
    echo "=====  Doing some post chroot cleanup  ====="


    echo "---  Un-mounting system resources  ---"

    umount "$CHROOT_TO"/proc

    if [ -d "/proc/ish" ]; then
        echo "---  Removing the temp /dev entries"
        rm -f "$CHROOT_TO"/dev/*
    else
        # umount "$CHROOT_TO"/tmp
        umount "$CHROOT_TO"/sys
        umount "$CHROOT_TO"/dev
    fi
}

show_help() {
    cat <<EOF
Usage: $prog_name [-h] | [-u] | [-p dir] command

chroot with env setup so this works on both Linux & iSH

Available options:

-h, --help     Print this help and exit
-c  --cleanup  Cleanup env
-p, --path     What dir to chroot into, defaults to: $BUILD_ROOT_D
command        What to run, defaults to "bash -l", command params must be quoted!
EOF

}



case "$1" in

    "-h" | "--help" )
        show_help
        exit 0
        ;;

    "-p" | "--path" )
        if [ -n "$2" ]; then
            CHROOT_TO="$2"
            if [ ! -d "$CHROOT_TO" ]; then
                echo "ERROR: [$CHROOT_TO] is not a directory!"
                exit 1
            fi
            shift  # get rid of the option
            shift  # get rid of the dir
        else
            echo "ERROR: -p assumes a param pointing to where to chroot!"
            exit 1
        fi
        ;;

    "-c" | "--cleanup" )
        env_cleanup
        exit 0
        ;;

    *)
        firstchar="$(echo "$1" | cut -c1-1)"
        if [ "$firstchar" = "-" ]; then
            echo "ERROR: invalid option! Try using: -h"
            exit 1
        fi
        ;;

esac



env_prepare


if [ "$1" = "" ]; then
    cmd="bash -l"
else
    cmd="$1"
fi

echo "=====  chrooting to: $CHROOT_TO ($cmd)  ====="

# In this case we want the $cmd variable to expand into its components
# shellcheck disable=SC2086
chroot "$CHROOT_TO" $cmd
exit_code="$?"


env_cleanup

# If there was an error in the chroot process, propagate it
exit "$exit_code"