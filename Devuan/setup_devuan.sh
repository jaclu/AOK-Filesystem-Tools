#!/bin/sh
#
#  Part of https://github.com/jaclu/AOK-Filesystem-Tools
#
#  License: MIT
#
#  Copyright (c) 2024: Jacob.Lundqvist@gmail.com
#
#  setup_devuan.sh
#
#  This modifies a Devuan Linux FS with the AOK changes
#

setup_cron_env() {
    msg_2 "Setup Devuan cron"

    msg_3 "Adding root crontab running periodic content"
    mkdir -p /var/spool/cron/crontabs
    rsync_chown /opt/AOK/common_AOK/cron/crontab-root /var/spool/cron/crontabs/root

    #  shellcheck disable=SC2154
    if [ "$USE_CRON_SERVICE" = "Y" ]; then
        msg_3 "Activating cron service"
        # [ -z "$(command -v cron)" ] && error_msg "cron service requested, cron does not seem to be installed"
        rc-update add cron default
    else
        msg_3 "Inactivating cron service"
        #  Action only needs to be taken if it was active
        find /etc/runlevels | grep -q cron && rc-update del cron default
    fi
    # msg_3 "setup_cron_env() - done"
}

devuan_services() {
    #
    #  Setting up suitable services, and removing those not meaningfull
    #  on iSH
    #
    msg_2 "devuan_services()"
    msg_3 "Remove previous ssh host keys if present"
    rm -f /etc/ssh/ssh_host*key*

    setup_cron_env
}

not_install_sshd() {
    #
    #  Install sshd, then remove the service, in order to not leave it running
    #  unless requested to: with enable-sshd / disable_sshd
    #
    msg_1 "Installing openssh-server"

    msg_2 "Remove previous ssh host keys if present in FS to ensure not using known keys"
    rm -f /etc/ssh/ssh_host*key*

    openrc_might_trigger_errors

    msg_3 "Install sshd and sftp-server (scp server part)"
    apt install -y openssh-server openssh-sftp-server

    msg_3 "Disable sshd for now, enable it with: enable-sshd"
    rc-update del ssh default
}

#===============================================================
#
#   Main
#
#===============================================================

tsd_start="$(date +%s)"

[ -z "$d_aok_etc" ] && . /opt/AOK/tools/utils.sh

ensure_ish_or_chrooted ""

msg_script_title "setup_devuan.sh  Devuan specific AOK env"
initiate_deploy Devuan "$(cat /etc/devuan_version)"

$scr_setup_famdeb || error_msg "in $scr_setup_famdeb"

rsync_chown /opt/AOK/Devuan/etc/update-motd.d /etc

# setup_login
debian_services

replace_home_dirs

additional_prebuild_tasks

display_installed_versions_if_prebuilt

msg_1 "Devuan specific setup complete!"

duration="$(($(date +%s) - tsd_start))"
display_time_elapsed "$duration" "Setup Devuan"

complete_initial_setup
