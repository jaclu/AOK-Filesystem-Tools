#!/bin/sh
#
#  Part of https://github.com/jaclu/AOK-Filesystem-Tools
#
#  License: MIT
#
#  Copyright (c) 2023: Jacob.Lundqvist@gmail.com
#
#  Common setup tasks for both Alpine & Debian
#
# shellcheck disable=SC2154

copy_skel_files() {
    # echo "=V= copy_skel_files($1)"
    csf_dest="$1"
    if [ -z "$csf_dest" ]; then
        error_msg "copy_skel_files() needs a destination param"
    elif [ ! -d "$csf_dest" ]; then
        error_msg "copy_skel_files($csf_dest) - not indicating a directory"
    fi

    #
    #  Ensure all files are owned by owner of the containing folder after
    #  skel copy
    #
    csf_owner="$(find "$csf_dest" -maxdepth 0 -printf "%u:%g")"
    rsync -a --chown="$csf_owner" /etc/skel/ "$csf_dest"

    unset csf_dest
    unset csf_owner
    # echo "^^^ copy_skel_files($1) - done"
}

user_shell() {
    #
    #  If USER_SHELL has been defined, the assumption would be to use
    #  the same for user root, since if logins are not enabled,
    #  you wold start up as user root.
    #
    #  Only allow root to get bash or ash during deploy, in order to
    #  ensure /etc/profile will be launched and deployt can complete
    #

    if [ "$USER_SHELL" = "/bin/ash" ] || [ "$USER_SHELL" = "/bin/bash" ]; then
        msg_3 "Setting root shell into USER_SHELL: $USER_SHELL"
        awk -v shell="$USER_SHELL" -F: '$1=="root" {$NF=shell}1' OFS=":" \
            /etc/passwd >/tmp/passwd && mv /tmp/passwd /etc/passwd
    fi
}

handle_hardcoded_tz() {
    #
    #  If AOK_TIMEZONE is defined, TZ can be set as early as the tools
    #  needed for it are in. If it is not set, there will be a dialog
    #  at the end of the deploy where TZ can be selected
    #
    if [ -n "$AOK_TIMEZONE" ]; then
        #
        #  Need full path to handle that this path is not correctly cached at
        #  this point if Debian is being installed, probably due to switching
        #  from Alpine to Debian without having rebooted yet.
        #
        msg_2 "Setitng time zone"
        msg_3 "Using hardcoded TZ: $AOK_TIMEZONE"
        ln -sf "/usr/share/zoneinfo/$AOK_TIMEZONE" /etc/localtime
    fi
}

adding_runbg_service() {
    if command -v openrc >/dev/null; then
        msg_2 "Adding runbg service"
        rsync_chown /opt/AOK/common_AOK/etc/init.d/runbg /etc/init.d silent
        # openrc_might_trigger_errors
        rc-update add runbg default
    else
        msg_2 "openrc not available - runbg not activated"
        error_msg "><> openrc not available - runbg not activated"
    fi
}

removing_original_hostname_service() {
    #
    #  Removing default hostname service
    #
    hostn_service=/etc/init.d/hostname
    if [ -f "$hostn_service" ]; then
        msg_2 "Disabling hostname service not working on iSH"
        mv -f "$hostn_service" /etc/init.d/NOT-hostname
    fi
    if destfs_is_debian || destfs_is_devuan; then
        msg_3 "Removing hostname service files not meaningfull on iSH"
        rm -f /etc/init.d/hostname
        rm -f /etc/init.d/hostname.sh
        rm -f /etc/rcS.d/S01hostname.sh
        rm -f /etc/systemd/system/hostname.service
    fi
}

changing_sshd_port() {
    if [ -f /etc/ssh/sshd_config ]; then
        # Move sshd to port 1022 to avoid issues
        sshd_port=1022
        msg_2 "sshd will use port: $sshd_port"
        sed -i "/Port /c Port $sshd_port" /etc/ssh/sshd_config
        #sed -i "s/.*Port .*/Port $sshd_port/" /etc/ssh/sshd_config
        unset sshd_port
    else
        msg_2 "sshd not installed - port not changed"
    fi
}

setup_cron_env() {
    msg_2 "Setup general cron env"
    #
    #  These files will always be setup and ready
    #  The cron/dcron service will only be acrive
    #  if USE_CRON_SERVICE="Y >$f_hostname_org"
    #
    msg_3 "Setting cron periodic files"
    rsync_chown /opt/AOK/common_AOK/cron/periodic /etc silent
    #msg_3 "setup_cron_env() - done"
}

disabling_default_services() {
    #
    #  openrc is extreamly forgiving when it comes to dependencies, any
    #  dependency that is not pressent is simply ignored.
    #
    #  When doing start/stop no more weird openrc warnings from kernel
    #  related services that will always fail on iSH
    #
    #  Bootup time is vastly reduced, since openrc doesn't have to plow
    #  through essentially every init script due to complex and in our
    #  case pointless dependencies
    #
    msg_3 "Moving all unused services to /etc/init.d/NOT"
    mv /etc/init.d /etc/NOT
    mkdir /etc/init.d
    mv /etc/NOT /etc/init.d
    #  Keep the files we actually need
    if destfs_is_alpine; then
        cp -a /etc/init.d/NOT/sshd /etc/init.d
    else
        cp -a /etc/init.d/NOT/ssh /etc/init.d
        msg_4 "Preserving /etc/init.d/rc"
        cp -a /etc/init.d/NOT/rc /etc/init.d
    fi
    msg_4 "Unused files cleared from init.d"
}

setup_environment() {

    copy_local_bins common_AOK

    msg_2 "Configure some /etc files"

    #
    #  If the skel files are copied to /root during deploy, in a script run
    #  by root, it triggers a clear screen. Doing it at this point ensures
    #  that root env is already setup before dest root runs anything
    #

    msg_3 "Disabling login timeout"
    _f="/etc/login.defs"
    if [ -f "$_f" ]; then
        echo "LOGIN_TIMEOUT 0" >"$_f"
    else
        error_msg "Config file not found: >$_f<"
    fi

    msg_3 "Installing /etc/environment"
    cp /opt/AOK/common_AOK/etc/environment /etc

    msg_3 "Installing profile-hints file"
    cp /opt/AOK/common_AOK/etc/profile-hints /etc

    disabling_default_services

    msg_3 "Populate /etc/skel"
    rsync_chown /opt/AOK/common_AOK/etc/skel /etc silent

    msg_3 "Activating group sudo for no passwd sudo"
    cp /opt/AOK/common_AOK/etc/sudoers.d/sudo_no_passwd /etc/sudoers.d
    chmod 440 /etc/sudoers.d/sudo_no_passwd

    echo "This is an iSH node, running $(destfs_detect)" >/etc/issue

    echo >>/etc/issue

    user_shell
    handle_hardcoded_tz
    adding_runbg_service
    removing_original_hostname_service
    replacing_std_bins_with_aok_versions ""
    changing_sshd_port

    msg_2 "Set default aok preferences"
    if [ "$AOK_HOSTNAME_SUFFIX" = "Y" ]; then
        use_aok_suffix="on"
    else
        use_aok_suffix="off"
    fi
    aok -c off -H on -s "$use_aok_suffix"
    unset use_aok_suffix

    setup_cron_env

    echo # Spacer to next task

    #
    #  If chrooted inside tmux TERM causes whiptail to fail, set it to something
    #  safe. TODO: is still needed? If so move to where it is needed
    #
    # TERM=xterm
}

setup_root_env() {
    #
    #  Should be done before the first session by this user
    #
    msg_2 "Setting up root user env"

    #
    #  Extra sanity check, if this is undefined, the rest of this would
    #  ruin the build host root env...
    #
    [ ! -f "$f_host_deploy_state" ] && error_msg "setup_root_env() - This doesnt look like a FS during deploy!"
    [ -z "$d_build_root" ]

    #
    #  root user env
    #
    msg_3 "Use skel files for root"
    copy_skel_files /root

    msg_3 "clear root history"
    rm /root/.bash_history -f

    # msg_3 "setup_root_env() - done"
}

create_user() {
    msg_2 "Creating default user and group: $USER_NAME"
    if [ -z "$USER_NAME" ]; then
        msg_3 "No user requested"
        return
    fi

    cu_home_dir="/home/$USER_NAME"
    groupadd -g 501 "$USER_NAME"

    #
    #  Determine what shell to use for custom user
    #
    if [ -n "$USER_SHELL" ]; then
        if [ ! -x "${d_build_root}$USER_SHELL" ]; then
            error_msg "User shell not found: ${d_build_root} $USER_SHELL"
        fi
        use_shell="$USER_SHELL"
        msg_3 "User shell: $use_shell"
    else
        use_shell="$(command -v bash)"
        msg_3 "User shell (default): $use_shell"
    fi

    # temp changing UID_MIN is to silence the warning:
    # ish's uid 501 outside of the UID_MIN 1000 and UID_MAX 6000 range.
    #  add additional groups with -G
    useradd -m -s "$use_shell" -u 501 -g 501 -G sudo,root,adm "$USER_NAME" --key UID_MIN=501

    # shadow with blank ish password
    sed -i "s/${USER_NAME}:\!:/${USER_NAME}::/" /etc/shadow

    # Add dot files for ish
    copy_skel_files "$cu_home_dir"

    msg_3 "Adding documentation to userdir"
    cp -a /opt/AOK/Docs "$cu_home_dir"

    #  ensure that all files have right ownership
    chown -R "$USER_NAME": "$cu_home_dir"

    unset cu_home_dir
    # msg_3 "create_user() - done"
}

#===============================================================
#
#   Main
#
#===============================================================

# shellcheck source=/dev/null
[ -z "$d_aok_etc" ] && . /opt/AOK/tools/utils.sh

. /opt/AOK/tools/multi_use.sh

ensure_ish_or_chrooted

msg_script_title "setup_common_env.sh  Common AOK setup steps"

if ! command -v sudo >/dev/null; then
    #
    #  If sudo is not installed passwordless sudoers file cant be copied
    #  and sudo is a core part of AOK FS, so shuld always be pressent
    #
    error_msg "sudo not installed, common_AOK/setup_environment() can not complete"
fi

if ! command -v bash >/dev/null; then
    #
    #  Starting with this, some bash scripts need to be run
    #
    error_msg "bash not installed, common_AOK/setup_environment() can not complete"
fi

if [ -n "$USER_SHELL" ]; then
    if ! destfs_is_alpine && [ "$USER_SHELL" = "/bin/ash" ]; then
        msg_1 "Only Alpine has /bin/ash - USER_SHELL set to /bin/bash"
        USER_SHELL="/bin/bash"
    fi
    [ ! -x "$USER_SHELL" ] && error_msg "USER_SHELL ($USER_SHELL) can't be found!"
else
    if destfs_is_alpine; then
        USER_SHELL="/bin/ash"
    else
        USER_SHELL="/bin/bash"
    fi
    msg_2 "USER_SHELL was undefined, set to the default: $USER_SHELL"
fi

setup_environment
set_hostname
setup_root_env
create_user

msg_1 "setup_common_env.sh done"

exit 0 # indicate no error
