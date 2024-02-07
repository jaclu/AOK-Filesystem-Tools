#!/bin/sh
#
#  Part of https://github.com/jaclu/AOK-Filesystem-Tools
#
#  License: MIT
#
#  Copyright (c) 2023: Jacob.Lundqvist@gmail.com
#
#  Upgrades an already installed iSH to be current with /optAOK content
#  This is not equivallent to a fresh install, since dynamically generated
#  suff is better suited for a re-install.
#
#  Some sanity checks are done in order to move config and status files
#  when possible. Warnings will be printed if obsolete files are found.
#

restore_to_aok_state() {
    src="$1"
    dst="$2"        
    [ -z "$src" ] && error_msg "restore_to_aok_state() - no 1st param"
    [ -z "$dst" ] && error_msg "restore_to_aok_state() - no 2nd param"
    [ -e "$src" ] || error_msg "restore_to_aok_state() - src not found $src"
    #[ -e "$dst" ] || error_msg "restore_to_aok_state() - dst not found $dst"

    msg_2 "Will restore $src -> $dst"
    rsync_chown "$src" "$dst" || {
        error_msg "restore_to_aok_state() - Failed to copy $src -> $dst"
    }
}

do_restore_configs() {
    #
    #  This covers config style files, that might overwrite user configs
    #
    echo "===  Upgrade of configs is requested, will update /etc/inittab and similar configs"
    restore_to_aok_state /opt/AOK/common_AOK/etc/environment /etc
    restore_to_aok_state /opt/AOK/common_AOK/etc/profile-hints /etc
    restore_to_aok_state /opt/AOK/common_AOK/etc/init.d/runbg /etc/init.d/runbg
    restore_to_aok_state /opt/AOK/common_AOK/etc/login.defs /etc/login.defs
    restore_to_aok_state "$distro_prefix"/etc/inittab /etc/inittab
    restore_to_aok_state "$distro_prefix"/etc/profile /etc/profile
    restore_to_aok_state /opt/AOK/common_AOK/etc/skel /etc
    if hostfs_is_alpine; then
        restore_to_aok_state "$distro_prefix"/etc/motd_template /etc/motd_template
    elif hostfs_is_debian; then
        restore_to_aok_state "$distro_prefix"/etc/pam.d /etc
        restore_to_aok_state "$distro_prefix"/etc/update-motd.d /etc
    elif hostfs_is_devuan; then
        restore_to_aok_state "$distro_prefix"/etc/pam.d /etc
        restore_to_aok_state "$distro_prefix"/etc/update-motd.d /etc
    fi
    echo
}

is_obsolete_file_present() {
    f_name="$1"
    [ -z "$f_name" ] && error_msg "is_obsolete_file_present() - no first param"

    if [ -f "$f_name" ]; then
        msg_3 "Obsolete file found: $f_name"
    elif [ -e "$f_name" ]; then
        msg_3 "Obsolete filename found, but was not file: $f_name"
    fi
}

general_upgrade() {

    msg_1 "Upgrading /usr/local/bin & /usr/local/sbin"

    # this name was used up to arround 11.0
    mv_no_over_write /etc/aok-release /etc/aok-fs-release

    #
    #  Always copy common stuff
    #
    msg_2 "Common stuff"
    msg_3 "/usr/local/bin"
    rsync_chown /opt/AOK/common_AOK/usr_local_bin/ /usr/local/bin
    msg_3 "/usr/local/sbin"
    rsync_chown /opt/AOK/common_AOK/usr_local_sbin/ /usr/local/sbin
    echo
    msg_3 "alternate hostname related"
    [ -f /etc/init.d/hostname ] && rsync_chown /opt/AOK/common_AOK/hostname_handling/aok-hostname-service /etc/init.d/hostname
    # [ -f /usr/local/bin/hostname ] && rsync_chown /opt/AOK/common_AOK/hostname_handling/hostname_alt /usr/local/bin/hostname
    # [ -f /usr/local/sbin/hostname_sync.sh ] && rsync_chown /opt/AOK/common_AOK/hostname_handling/hostname_sync.sh /usr/local/sbin
    echo

    msg_3 "runbg"
    rsync_chown /opt/AOK/common_AOK/etc/init.d/runbg /etc/init.d
    #
    #  Copy distro specific stuff
    #
    if hostfs_is_alpine; then
        msg_2 "Alpine specifics"
        msg_3 "/usr/local/bin"
        rsync_chown /opt/AOK/Alpine/usr_local_bin/ /usr/local/bin
        msg_3 "/usr/local/sbin"
        rsync_chown /opt/AOK/Alpine/usr_local_sbin/ /usr/local/sbin
    elif hostfs_is_debian; then
        msg_2 "Debian specifics"
        msg_3 "/usr/local/bin"
        rsync_chown /opt/AOK/Debian/usr_local_bin/ /usr/local/bin
        msg_3 "/usr/local/sbin"
        rsync_chown /opt/AOK/Debian/usr_local_sbin/ /usr/local/sbin
        rsync_chown /opt/AOK/Debian/etc/init.d/rc /etc/init.d
    elif hostfs_is_devuan; then
        msg_2 "Devuan specifics"
        msg_3 "/usr/local/bin"
        rsync_chown /opt/AOK/Devuan/usr_local_bin/ /usr/local/bin
        msg_3 "/usr/local/sbin"
        rsync_chown /opt/AOK/Devuan/usr_local_sbin/ /usr/local/sbin
    else
        error_msg "Failed to recognize Distro, aborting."
    fi
    echo
}

mv_no_over_write() {
    _f_src="$1"
    _f_dst="$2"
    [ -z "$_f_src" ] && error_msg "mv_no_over_write() - no first param"
    [ -f "$_f_src" ] || return # if src isnt there, nothing to move
    [ -z "$_f_dst" ] && error_msg "mv_no_over_write() - no destination"
    [ -f "$_f_dst" ] && error_msg "can't move $_f_src to $_f_dst - destination occupied: $_f_dst"

    if mv "$_f_src" "$_f_dst"; then
        msg_3 "Moved $_f_src -> $_f_dst"
    else
        error_msg "Failed to move: $_f_src -> $_f_dst"
    fi
}

move_file_to_right_location() {
    f_old="$1"
    f_new="$2"
    [ -z "$f_old" ] && error_msg "move_file_to_right_location() - no first param"
    [ -z "$f_new" ] && error_msg "move_file_to_right_location() - no second param"
    [ -z "$d_new_etc_opt_prefix" ] && error_msg "d_new_etc_opt_prefix not defined"

    [ -f "$f_old" ] || return # nothing to move

    mkdir -p "$d_new_etc_opt_prefix"

    [ "${f_new%"$d_new_etc_opt_prefix/"*}" != "$f_new" ] || {
        error_msg "destination incorrect: $f_new - should start with $d_new_etc_opt_prefix"
    }
    mv_no_over_write "$f_old" "$f_new"
    echo
}

update_etc_opt_references() {
    #
    #  Correct old filenames  - last updated 23-12-03
    #
    msg_2 "Migrating obsolete /etc/opt files to $d_new_etc_opt_prefix"
    move_file_to_right_location /etc/opt/tmux_nav_key_handling \
        "$d_new_etc_opt_prefix/tmux_nav_key_handling"
    move_file_to_right_location /etc/opt/tmux_nav_key \
        "$d_new_etc_opt_prefix/tmux_nav_key"
    move_file_to_right_location /etc/opt/hostname_source_fname \
        "$d_new_etc_opt_prefix/hostname_source_fname"

    move_file_to_right_location /etc/opt/AOK-FS/tmux_nav_key_handling \
        "$d_new_etc_opt_prefix/tmux_nav_key_handling"
    move_file_to_right_location /etc/opt/AOK-FS/tmux_nav_key \
        "$d_new_etc_opt_prefix/tmux_nav_key"
    move_file_to_right_location /etc/opt/AOK-FS/hostname_source_fname \
        "$d_new_etc_opt_prefix/hostname_source_fname"

    move_file_to_right_location /etc/opt/AOK/default-login-username \
        "$d_new_etc_opt_prefix/login-default-username"
    move_file_to_right_location /etc/opt/AOK/continous-logins \
        "$d_new_etc_opt_prefix/login-continous"
}

obsolete_files() {
    msg_2 "Ensuring no obsolete files are present"

    is_obsolete_file_present /etc/aok-release
    is_obsolete_file_present /etc/init.d/bat_charge_log
    is_obsolete_file_present /etc/opt/AOK-login_method
    is_obsolete_file_present /etc/opt/hostname_cached

    is_obsolete_file_present /usr/local/bin/aok_groups
    is_obsolete_file_present /usr/local/bin/apk_find_pkg
    is_obsolete_file_present /usr/local/bin/battery_charge
    is_obsolete_file_present /usr/local/bin/disable_sshd
    is_obsolete_file_present /usr/local/bin/disable_vnc
    is_obsolete_file_present /usr/local/bin/elock
    is_obsolete_file_present /usr/local/bin/enable_sshd
    is_obsolete_file_present /usr/local/bin/enable_vnc
    is_obsolete_file_present /usr/local/bin/fake_syslog
    is_obsolete_file_present /usr/local/bin/ipad_tmux
    is_obsolete_file_present /usr/local/bin/iphone_tmux
    is_obsolete_file_present /usr/local/bin/nav_keys.sh
    is_obsolete_file_present /usr/local/bin/network_check.sh
    is_obsolete_file_present /usr/local/bin/toggle_multicore
    is_obsolete_file_present /usr/local/bin/vnc_start
    is_obsolete_file_present /usr/local/bin/vnc_stop
    is_obsolete_file_present /usr/local/bin/what_owns
    is_obsolete_file_present /usr/local/sbin/aok-launcher
    is_obsolete_file_present /usr/local/sbin/bat_charge_leveld
    is_obsolete_file_present /usr/local/sbin/bat_monitord
    is_obsolete_file_present /usr/local/sbin/do_shutdown
    is_obsolete_file_present /usr/local/sbin/ensure_hostname_in_host_file.sh
    is_obsolete_file_present /usr/local/sbin/ensure_hostname_in_host_file
    is_obsolete_file_present /usr/local/sbin/hostname_sync.sh
    is_obsolete_file_present /usr/local/sbin/reset-run-dir.sh
    is_obsolete_file_present /usr/local/sbin/update_motd
}

update_aok_release() {
    f_aok_release=/etc/aok-fs-release
    msg_2 "Updating $f_aok_release to current release"
    read -r old_release <"$f_aok_release"
    if [ -z "$old_release" ]; then
        error_msg "Failed to read old release, leaving it as is" noexit
    fi

    splitter="-JL-"

    # Use awk to split the string based on '-JL-'
    #aok_release=$(echo "$old_release" | awk -v splitter="$splitter" -F "$splitter" '{print $1}')
    sub_release=$(echo "$old_release" | awk -v splitter="$splitter" -F "$splitter" '{print $2}')
    new_rel="$(grep AOK_VERSION /opt/AOK/AOK_VARS | cut -d= -f 2 | sed 's/\"//g')"
    #
    #  If there is no sub release, set it to an empty string, otherwise
    #  re-add splitter
    #
    [ -z "$sub_release" ] && sub_release='' || sub_release="$splitter$sub_release"

    if true; then
        new_rel="$(grep AOK_VERSION /opt/AOK/AOK_VARS | cut -d= -f 2 | sed 's/\"//g')$sub_release"
    fi

    echo "$new_rel" >"$f_aok_release".new

    if diff -q "$f_aok_release" "$f_aok_release".new; then
        echo "><> versions differ"
        #  Update the release file
        cp "$f_aok_release" "$f_aok_release".old
        mv "$f_aok_release".new "$f_aok_release"
        msg_1 "Updated $f_aok_release to: $new_rel"
        if hostfs_is_alpine; then
            /usr/local/sbin/update-motd
        fi
    else
        echo "><> versions same"
        rm "$f_aok_release".new
    fi
}

#===============================================================
#
#   Main
#
#===============================================================

hide_run_as_root=1 . /opt/AOK/tools/run_as_root.sh
. /opt/AOK/tools/utils.sh

ensure_ish_or_chrooted

if hostfs_is_alpine; then
    distro_prefix="/opt/AOK/Alpine"
elif hostfs_is_debian; then
    distro_prefix="/opt/AOK/Debian"
else
    error_msg "cron service not available for this FS"
fi

d_new_etc_opt_prefix="/etc/opt/AOK"

#this_is_ish || error_msg "This should only be run on an iSH platform!"

if [ "$1" = "configs" ]; then
    echo
    do_restore_configs
fi

general_upgrade
update_etc_opt_references
update_aok_release
verify_launch_cmd
obsolete_files