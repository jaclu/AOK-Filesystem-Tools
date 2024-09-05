#!/bin/sh
#  shellcheck disable=SC2154
#
#  Part of https://github.com/jaclu/AOK-Filesystem-Tools
#
#  Copyright (c) 2023: Jacob.Lundqvist@gmail.com
#
#  License: MIT
#
#  setup_alpine.sh
#
#  This modifies an Alpine Linux FS with the AOK changes
#

find_fastest_mirror() {
    msg_1 "Find fastest mirror"
    apk add alpine-conf || {
        error_msg "apk add alpine-conf failed"
    }
    setup-apkrepos -f
}

removing_unwanted_package() {
    # removes all packages listed as params
    rup_pkg="$1"
    [ -z "$1" ] && {
        error_msg "removing_unwanted_package() - called without param"
    }
    while [ -n "$1" ]; do
        rup_pkg="$1"
        msg_3 "removing $rup_pkg from CORE_APKS"
        CORE_APKS="$(echo "$CORE_APKS" | sed "s/$rup_pkg//")"
        shift
    done
}

handle_apks() {

    alpine_apk_update
    msg_1 "apk upgrade"
    apk upgrade || {
        error_msg "apk upgrade failed"
    }
    echo

    if ! min_release "3.16"; then
        if [ -z "${CORE_APKS##*shadow-login*}" ]; then
            msg_2 "Excluding packages not yet availabe before 3.16"
            removing_unwanted_package shadow-login
            removing_unwanted_package py3-pendulum
            removing_unwanted_package zsh-completions
            removing_unwanted_package zsh-history-substring-search
        fi
    fi
    #if ! min_release 3.15; then
    #    msg_2 "Pre 3.15 procps was called procps-ng"
    #    CORE_APKS="$(echo "$CORE_APKS" | sed 's/procps/procps-ng/')"
    #fi
    min_release "3.19" && {
        msg_1 "iSH has some limitations on the latest releases..."

        if min_release "3.20"; then
            msg_2 "Alpine >= 3.20 - coreutils cant be used"
            removing_unwanted_package coreutils
        fi

        # 3.19 and higher will insta-die if the default sudo is used....
        msg_2 "Alpine >= 3.19 - sudo from 3.18 must be used"
        apk add sudo=1.9.13_p3-r2 \
            --repository=https://dl-cdn.alpinelinux.org/alpine/v3.18/community
        removing_unwanted_package sudo

        # 3.19 and higher has stability issues with modern sqlite
        msg_2 "Alpine >= 3.19 - sqlite from 3.18 is recomended"
        apk add sqlite=3.41.2-r3 sqlite-libs=3.41.2-r3 \
            --repository=https://dl-cdn.alpinelinux.org/alpine/v3.18/main
        removing_unwanted_package sqlite sqlite-libs
    }

    if [ -n "$CORE_APKS" ]; then
        msg_1 "Install core packages"
        echo "$CORE_APKS"
        echo

        # In this case we want the variable to expand into its components
        # shellcheck disable=SC2086 # in this case variable should expand
        apk add $CORE_APKS || {
            error_msg "apk add CORE_APKS failed"
        }
        echo
    else
        msg_1 "No CORE_APKS defined"
    fi

    if [ -n "$AOK_PKGS_SKIP" ]; then
        msg_1 "Removing packages"
        echo "$AOK_PKGS_SKIP"
        echo

        # In this case we want the variable to expand into its components
        # shellcheck disable=SC2086 # in this case variable should expand
        apk del $AOK_PKGS_SKIP || error_msg "Failed to delete AOK_PKGS_SKIP"
        echo
    fi

    echo
    Mapk || error_msg "Mapk reported error"
}

prepare_env_etc() {
    msg_2 "prepare_env_etc() - Replacing a few /etc files"

    msg_3 "AOK inittab"
    cp /opt/AOK/Alpine/etc/inittab /etc

    msg_3 "iOS interfaces file"
    cp /opt/AOK/Alpine/etc/interfaces /etc/network

    if [ -f /etc/init.d/devfs ]; then
        msg_3 "Linking /etc/init.d/devfs <- /etc/init.d/dev"
        ln /etc/init.d/devfs /etc/init.d/dev
    fi

    min_release 3.20 && {
        #
        #  Starting with this release, an empty Last Password Change
        #  for root in /etc/shadow will trigger the harmless warning
        #    Warning: your password will expire in 0 days.
        #  to be displayed when doing: sudo su
        # Setting it to anything but the default 0 will solve this.
        #
        msg_2 "Fixing warning about password expire when doing sudo su"
        sed -i '/^root/c\root:*:1:0:::::' /etc/shadow
    }
}

setup_cron_env() {
    msg_2 "Setup Alpine dcron"

    msg_3 "Adding root crontab running periodic content"
    mkdir -p /etc/crontabs
    cp -a /opt/AOK/common_AOK/cron/crontab-root /etc/crontabs/root

    #  shellcheck disable=SC2154
    if [ "$USE_CRON_SERVICE" = "Y" ]; then
        msg_3 "Activating dcron service, but not starting it now"
        [ "$(command -v crond)" != /usr/sbin/crond ] && error_msg "cron service requested, dcron does not seem to be installed"
        rc-update add dcron default
    else
        msg_3 "Inactivating cron service"
        #  Action only needs to be taken if it was active
        find /etc/runlevels/ | grep -q dcron && rc-update del dcron default
    fi
    # msg_3 "setup_cron_env() - done"
}

#===============================================================
#
#   Main
#
#===============================================================

tsa_start="$(date +%s)"

[ -z "$d_aok_etc" ] && . /opt/AOK/tools/utils.sh

ensure_ish_or_chrooted ""

if [ -z "$ALPINE_VERSION" ]; then
    error_msg "ALPINE_VERSION param not supplied"
fi

# deploy_starting
msg_script_title "setup_alpine.sh - Setup Alpine"
initiate_deploy Alpine "$ALPINE_VERSION"

this_is_aok_kernel && min_release "3.20" && {
    echo
    echo "On iSH-AOK rsync and other core bins will fail in Alpine 3.20"
    error_msg "For now using Alpine 3.19 or older is recomended"
}

prepare_env_etc
handle_apks

msg_2 "adding group sudo"
groupadd sudo

if ! "$scr_setup_common_env"; then
    error_msg "$scr_setup_common_env reported error"
fi

msg_2 "Copy /etc/motd_template"
cp -a /opt/AOK/Alpine/etc/motd_template /etc

msg_2 "Copy iSH compatible pam base-session"
cp -a /opt/AOK/Alpine/etc/pam.d/base-session /etc/pam.d

#
#  Extra sanity check, only continue if there is a runable /bin/login
#
if [ ! -x "$(readlink -f /bin/login)" ]; then
    error_msg "CRITICAL!! no run-able /bin/login present!"
fi

msg_2 "Preparing initial motd"
/usr/local/sbin/update-motd

setup_cron_env

replace_home_dirs

additional_prebuild_tasks

/usr/local/bin/check-env-compatible

display_installed_versions_if_prebuilt

msg_1 "Setup complete!"

duration="$(($(date +%s) - tsa_start))"
display_time_elapsed "$duration" "Setup Alpine"

complete_initial_setup
