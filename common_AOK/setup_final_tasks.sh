#!/bin/sh
# this is sourced, shebang just to hint editors since no extension
#
#  Part of https://github.com/jaclu/AOK-Filesystem-Tools
#
#  License: MIT
#
#  Copyright (c) 2023: Jacob.Lundqvist@gmail.com
#
#  setup_final_tasks.sh
#
#  Completes the setup of AOK-FS
#  On normal installs, this runs at the end of the install.
#  On pre-builds this will be run on first boot at destination device,
#  so it can be assumed this is running on deploy destination
#

#
#  If aok_launcher is used as Launch Cmd, it has already waited for
#  system to be ready, so can be skipped here
#
wait_for_bootup() {
    # msg_2 "wait_for_bootup()"
    if [ "$(get_launch_cmd)" != "$launch_cmd_AOK" ]; then
        if deploy_state_is_it "$deploy_state_pre_build" &&
            ! hostfs_is_devuan &&
            ! this_fs_is_chrooted; then
            msg_2 "Waiting for runlevel default to be ready, normally < 10s"
            msg_3 "iSH sometimes fails this, so if this doesnt move on, try restarting iSH"
            while ! rc-status -r | grep -q default; do
                msg_3 "not ready"
                sleep 2
            done
        fi
    else
        msg_2 "Boot wait already handled by AOK Launch cmd"
    fi
    # msg_3 "wait_for_bootup() - done"
}

ensure_path_items_are_available() {
    #
    #  If this is run on an iOS device with limited storage, config
    #  items located on iCloud mounts might not be synced.
    #  Simplest thing is to look through config items that might contain
    #  files or directories, and ensuring those items are present.
    #  Any further specific sync are better done in
    #  FIRST_BOOT_ADDITIONAL_TASKS, where precise knowledge of that
    #  device should make specific requirements self explanatory.
    #
    msg_2 "Ensure path items pottentially on iCloud are available"

    # shellcheck disable=SC2154
    items_to_check="\
        $HOME_DIR_USER \
        $HOME_DIR_ROOT \
        $POPULATE_FS \
        $FIRST_BOOT_ADDITIONAL_TASKS \
        $ALT_HOSTNAME_SOURCE_FILE \
        $CUSTOM_FILES_TEMPLATE"

    while true; do
        one_item="${items_to_check%% *}"
        items_to_check="${items_to_check#* }"
        if [ -e "$one_item" ]; then
            msg_3 "Ensuring it is synced: $one_item"
            find "$one_item" >/dev/null
        fi
        [ "$one_item" = "$items_to_check" ] && break # we have processed last item
    done

    unset items_to_check
    unset one_item
    # msg_3 "ensure_path_items_are_available() - done"
}

aok_kernel_consideration() {
    msg_2 "aok_kernel_consideration()"
    this_is_aok_kernel || {
        msg_3 "Not aok kernel!"
        min_release 3.18 || {
            msg_3 "procps wont work on regular iSH for Alpine < 3.18"
            apk del procps || {
                error_msg "apk del procps failed"
            }
        }
        return
    }

    [ -n "$AOK_APKS" ] && {
        msg_3 "Install packages only for AOK kernel"
        # In this case we want the variable to expand into its components
        # shellcheck disable=SC2086
        apk add $AOK_APKS || {
            error_msg "apk add AOK_APKS failed"
        }
    }

    # shellcheck disable=SC2154
    this_is_aok_kernel && [ "$AOK_HOSTNAME_SUFFIX" = "Y" ] && {
        msg_3 "Using -aok suffix"
        aok -s on
    }
    # msg_3 "aok_kernel_consideration() - done"
}

verify_alpine_uptime() {
    #
    #  Some versions of uptime doesnt work in iSH, test and
    #  replace with softlink to busybox if that is the case
    #
    uptime_cmd="$(command -v uptime)"
    uptime_cmd_real="$(realpath "$uptime_cmd")"

    [ "$uptime_cmd_real" = "/bin/busybox" ] && return

    "$uptime_cmd" >/dev/null 2>&1 || {
        msg_2 "WARNING: Installed uptime not useable!"
        msg_3 "changing it to busybox symbolic link"
        rm -f "$uptime_cmd"
        ln -sf /bin/busybox "$uptime_cmd"
    }
}

start_cron_if_active() {
    msg_2 "start_cron_if_active()"
    #  shellcheck disable=SC2154
    [ "$USE_CRON_SERVICE" != "Y" ] && return

    if this_fs_is_chrooted || ! this_is_ish; then
        error_msg "Cant attempt to start cron on a chrooted/non-iSH device"
    fi

    cron_service="/etc/init.d"
    if hostfs_is_alpine; then
        cron_service="$cron_service/dcron"
    elif hostfs_is_debian; then
        cron_service="$cron_service/cron"
    else
        error_msg "cron service not available for this FS"
    fi

    openrc_might_trigger_errors
    [ ! -x "$cron_service" ] && error_msg "Cron service not found: $cron_service"
    if ! "$cron_service" status >/dev/null; then
        msg_3 "Starting cron service"
        "$cron_service" start
    fi
    # msg_3 "start_cron_if_active() - done"
}

deploy_bat_monitord() {
    s_name="bat-monitord"

    msg_2 "Battery monitor service $s_name"

    this_is_aok_kernel || {
        msg_3 "$s_name is only meaningfull on iSH-AOK, skipping"
        return
    }

    msg_3 "Adding $s_name service"
    cp -a /opt/AOK/common_AOK/etc/init.d/bat-monitord /etc/init.d
    rc-update add "$s_name" default
    msg_3 "Not starting it during deploy, it will start on next boot"
    #rc-service "$s_name" restart

    msg_2 "service $s_name installed and enabled"
    echo
}

run_additional_tasks_if_found() {
    msg_2 "run_additional_tasks_if_found()"

    [ -n "$FIRST_BOOT_ADDITIONAL_TASKS" ] && {
        msg_1 "Running additional final setup tasks"
        echo "---------------"
        echo "$FIRST_BOOT_ADDITIONAL_TASKS"
        echo "---------------"
        /bin/sh -c "$FIRST_BOOT_ADDITIONAL_TASKS" || {
            error_msg "FIRST_BOOT_ADDITIONAL_TASKS returned error"
        }
        msg_1 "Returned from the additional setup tasks"
    }
    # msg_3 "run_additional_tasks_if_found()  done"
}

clean_up_dest_env() {
    msg_2 "clear deploy state"
    rm "$f_dest_fs_deploy_state"

    rm -f "$f_home_user_replaced"
    rm -f "$f_home_root_replaced"
    rm -f "$f_hostname_initial"

    # dont remove if final dest is chrooted!
    if this_fs_is_chrooted; then
        msg_3 "dest is chrooted - Leaving: $f_chroot_hostname"
    else
        rm -f "$f_chroot_hostname"
    fi
}

#===============================================================
#
#   Main
#
#===============================================================

prog_name_sft=$(basename "$0")
tsaft_start="$(date +%s)"
echo
echo "=_=_="
echo "=====   $prog_name_sft started $(date)   ====="
echo "=_=_="
echo

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[ -z "$d_aok_etc" ] && . /opt/AOK/tools/utils.sh
. /opt/AOK/tools/ios_version.sh
. /opt/AOK/tools/user_interactions.sh

deploy_state_set "$deploy_state_finalizing"
msg_script_title "$prog_name_sft - Final part of setup"

set_hostname # it might have changed since pre-build...

hostfs_name="$(hostfs_detect)"
f_fs_final_tasks=/opt/AOK/"$hostfs_name"/setup_final_tasks.sh
[ -f "$f_fs_final_tasks" ] && {
    msg_1 "Running $hostfs_name final tasks"
    "$f_fs_final_tasks" || error_msg "$f_fs_final_tasks failed"
    msg_2 "$hostfs_name final tasks - done"
    echo
}

this_is_ish && wait_for_bootup

#
#  Setting up chroot env to use aok_launcher
#
if this_fs_is_chrooted; then
    _f="/usr/local/sbin/aok_launcher"
    msg_2 "Preparing chroot environment"
    msg_3 "Setting default chroot app: $_f"
    echo "$_f" >/.chroot_default_cmd
    [ -z "$USER_NAME" ] && aok -a "root"
else
    msg_2 "Setting Launch Cmd to: $launch_cmd_AOK"
    set_launch_cmd "$launch_cmd_AOK"
fi

[ -n "$USER_NAME" ] && {
    msg_3 "Enabling Autologin for $USER_NAME"
    aok -a "$USER_NAME"
}

if test -f /AOK; then
    msg_1 "Removing obsoleted /AOK new location is /opt/AOK"
    rm -rf /AOK
fi

user_interactions
ensure_path_items_are_available

#
#  Currently Debian doesnt seem to have to take the iSH app into
#  consideration
#
hostfs_is_alpine && aok_kernel_consideration

deploy_bat_monitord

if hostfs_is_alpine; then
    next_etc_profile="/opt/AOK/Alpine/etc/profile"
    #
    #  Some versions of Alpine uptime doesnt work in ish, test and
    #  replace with softlink to busybox if that is the case
    #
    verify_alpine_uptime
elif hostfs_is_debian || hostfs_is_devuan; then
    next_etc_profile="/opt/AOK/FamDeb/etc/profile"
else
    error_msg "Undefined Distro, cant set next_etc_profile"
fi

set_new_etc_profile "$next_etc_profile"

# to many issues - not worth it will start after reboot anyhow
# start_cron_if_active

#
#  Handling custom files
#
/opt/AOK/common_AOK/custom/custom_files.sh || {
    error_msg "common_AOK/custom/custom_files.sh failed"
}

replace_home_dirs
run_additional_tasks_if_found

duration="$(($(date +%s) - tsaft_start))"
display_time_elapsed "$duration" "Setup Final tasks"

verify_launch_cmd
clean_up_dest_env

msg_1 "File system deploy completed"

/usr/local/bin/aok-versions

echo "Setup has completed the last deploy steps and is ready!
You are recomended to reboot in order to ensure that all services are started,
and your environment is used."

#
#  This ridiculous extra step is needed if chrooted on iSH
#
cd / || error_msg "Failed to cd /"
cd || error_msg "Failed to cd home"
