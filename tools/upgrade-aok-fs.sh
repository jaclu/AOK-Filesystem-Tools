#!/bin/sh
#
#  Part of https://github.com/jaclu/AOK-Filesystem-Tools
#
#  License: MIT
#
#  Copyright (c) 2022-2024: Jacob.Lundqvist@gmail.com
#
#  Upgrades an already installed iSH to be current with /optAOK content
#  This is not equivallent to a fresh install, since dynamically generated
#  suff is better suited for a re-install.
#
#  Some sanity checks are done in order to move config and status files
#  when possible. Warnings will be printed if obsolete files are found.
#

show_help() {
    echo "Usage: $prog_name [-h] [-c]

This upgrades the iSH-AOK filesystem.

Available options:

-h  --help     Print this help and exit
-c  --configs  Updates config files
"
    exit 0
}

verify_launch_cmd() {
    this_is_ish || return

    msg_2 "Verifying expected 'Launch cmd'"

    launch_cmd_current="$(get_kernel_default launch_command)"
    if [ "$launch_cmd_current" != "$launch_cmd_AOK" ]; then
        msg_1 "'Launch cmd' is not the default for AOK"
        echo "Current 'Launch cmd': '$launch_cmd_current'"
        echo
        echo "To set the default, run this, it will display the updated content:"
        echo
        echo "aok --launch-cmd aok"
        echo
    fi
}

restore_to_aok_state() {
    src="$1"
    dst="$2"
    [ -z "$src" ] && error_msg "restore_to_aok_state() - no 1st param"
    [ -z "$dst" ] && error_msg "restore_to_aok_state($src,) - no 2nd param"
    [ -e "$src" ] || {
        error_msg "restore_to_aok_state($src, $dst) - src not found $src"
    }
    #[ -e "$dst" ] || error_msg "restore_to_aok_state() - dst not found $dst"

    msg_2 "Will restore $src -> $dst"
    rsync_chown "$src" "$dst" || {
        error_msg "restore_to_aok_state() - Failed to copy $src -> $dst"
    }
}

restore_configs() {
    #
    #  This covers config style files, that might overwrite user configs
    #
    _s="===  Upgrade of configs is requested, will update"
    _s="$_s /etc/inittab and similar configs"
    echo "$_s"
    restore_to_aok_state /opt/AOK/common_AOK/etc/environment /etc
    restore_to_aok_state /opt/AOK/common_AOK/etc/profile-hints /etc

    restore_to_aok_state /opt/AOK/common_AOK/etc/init.d/runbg /etc/init.d/runbg
    _f=/etc/runlevels/default/runbg
    [ ! -f "$_f" ] && {
        msg_3 "Soft-linking $_f"
        ln -sf /etc/init.d/runbg "$_f" || {
            error_msg "soft-linking failed!"
        }
    }

    restore_to_aok_state /opt/AOK/common_AOK/etc/login.defs /etc/login.defs
    restore_to_aok_state "$distro_fam_prefix"/etc/inittab /etc/inittab
    restore_to_aok_state "$distro_fam_prefix"/etc/profile /etc/profile
    restore_to_aok_state /opt/AOK/common_AOK/etc/skel /etc
    if fs_is_alpine; then
        restore_to_aok_state "$distro_prefix"/etc/motd_template /etc/motd_template
    elif fs_is_debian; then
        restore_to_aok_state "$distro_fam_prefix"/etc/pam.d /etc
        restore_to_aok_state "$distro_fam_prefix"/etc/update-motd.d /etc
        restore_to_aok_state "$distro_prefix"/etc/update-motd.d /etc
    elif fs_is_devuan; then
        restore_to_aok_state "$distro_fam_prefix"/etc/pam.d /etc
        restore_to_aok_state "$distro_prefix"/etc/update-motd.d /etc
    fi
    echo
}

is_obsolete_file_present() {
    f_name="$1"
    [ -z "$f_name" ] && error_msg "is_obsolete_file_present() - no first param"

    if [ -f "$f_name" ]; then
        echo "WARNING: Obsolete file found: $f_name"
    elif [ -e "$f_name" ]; then
        echo "WARNING: Obsolete filename found, but was not file: $f_name"
    fi
}

should_be_softlink() {
    f_name="$1"
    f_linked_to="$2"
    f_org_name="$3"
    [ -z "$f_name" ] && error_msg "should_be_softlink() - no first param"
    [ -z "$f_linked_to" ] && error_msg "should_be_softlink() - no 2nd param"

    [ ! -f "$f_linked_to" ] && {
        error_msg "source for sof link missing: $f_linked_to"
    }
    [ -L "$f_name" ] || error_msg "Should be softlink: $f_name"
    [ "$(realpath "$f_name")" != "$f_linked_to" ] && {
        error_msg "$f_name should be soft-linked to $f_linked_to"
    }
    [ -n "$f_org_name" ] && [ ! -f "$f_org_name" ] && {
        error_msg "Org-name file missing: $f_org_name"
    }
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

    #
    #  Copy distro specific stuff
    #
    if fs_is_alpine; then
        msg_2 "Alpine specifics"
        msg_3 "/usr/local/bin"
        rsync_chown /opt/AOK/Alpine/usr_local_bin/ /usr/local/bin
        msg_3 "/usr/local/sbin"
        rsync_chown /opt/AOK/Alpine/usr_local_sbin/ /usr/local/sbin

    elif fs_is_debian || fs_is_devuan; then
        msg_2 "Debian/Devuan specifics"
        msg_3 "/usr/local/bin"
        rsync_chown "$distro_fam_prefix"/usr_local_bin/ /usr/local/bin
        msg_3 "/usr/local/sbin"
        # kill_tail_logging is updated on each boot by aok_launcher
        _s="--exclude=kill_tail_logging $distro_fam_prefix/usr_local_sbin/"
        rsync_chown "$_s" /usr/local/sbin
        msg_3 "/etc/init.d/rc"
        rsync_chown "$distro_fam_prefix"/etc/init.d/rc /etc/init.d
    elif fs_is_gentoo; then
        msg_2 "Debian/Devuan specifics"
        msg_3 "Nothing here so far..."
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

    # undated
    is_obsolete_file_present /etc/aok-release
    is_obsolete_file_present /etc/init.d/bat_charge_log
    is_obsolete_file_present /etc/opt/AOK-login_method
    is_obsolete_file_present /etc/opt/hostname_cached

    # undated
    is_obsolete_file_present /etc/update-motd.d/11-aok-release
    is_obsolete_file_present /etc/update-motd.d/12-deb-vers
    is_obsolete_file_present /etc/update-motd.d/13-ish-release
    is_obsolete_file_present /etc/update-motd.d/25-aok-release
    is_obsolete_file_present /etc/update-motd.d/26-deb-vers
    is_obsolete_file_present /etc/update-motd.d/27-ish-release

    # 240819
    is_obsolete_file_present /usr/local/bin/network-check.sh
    # 240807
    is_obsolete_file_present /usr/local/bin/battery-charge
    # undated
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
    is_obsolete_file_present /usr/local/bin/shutdown
    is_obsolete_file_present /usr/local/bin/toggle_multicore
    is_obsolete_file_present /usr/local/bin/vnc_start
    is_obsolete_file_present /usr/local/bin/vnc_stop
    is_obsolete_file_present /usr/local/bin/what_owns

    # undated
    is_obsolete_file_present /usr/local/sbin/aok-launcher
    is_obsolete_file_present /usr/local/sbin/bat_charge_leveld
    is_obsolete_file_present /usr/local/sbin/bat_monitord
    is_obsolete_file_present /usr/local/sbin/custom_console_log.sh
    is_obsolete_file_present /usr/local/sbin/do_shutdown
    is_obsolete_file_present /usr/local/sbin/ensure_hostname_in_host_file.sh
    is_obsolete_file_present /usr/local/sbin/ensure_hostname_in_host_file
    is_obsolete_file_present /usr/local/sbin/poweroff
    is_obsolete_file_present /usr/local/sbin/hostname_sync.sh
    is_obsolete_file_present /usr/local/sbin/reset-run-dir.sh
    is_obsolete_file_present /usr/local/sbin/update_motd
    is_obsolete_file_present /usr/local/sbin/wait_for_console

}

check_softlinks() {
    msg_2 "Checking that softlinked bins are setup"

    replacing_std_bins_with_aok_versions upgrade
}

update_aok_release() {
    f_aok_release=/etc/aok-fs-release
    msg_2 "Updating $f_aok_release to current release"
    read -r old_release <"$f_aok_release"
    if [ -z "$old_release" ]; then
        error_msg "Failed to read old release, leaving it as is" -1
        return
    fi

    #
    #  Special handling of my custom release names
    #
    base_rel="$(cut -d'-' -f1 "$f_aok_release")"
    sub_rel="$(cut -d'-' -f2- "$f_aok_release")"
    new_rel="$(grep AOK_VERSION /opt/AOK/AOK_VARS | head -n 1 | cut -d= -f 2 | sed 's/\"//g' | cut -d'-' -f1)"
    [ "$base_rel" != "$sub_rel" ] && new_rel="$new_rel-$sub_rel"

    [ "$(cat "$f_aok_release")" != "$new_rel" ] && {
        #  Update the release file
        echo "$new_rel" >"$f_aok_release"
        msg_1 "Changed $f_aok_release to: $new_rel"
        if fs_is_alpine; then
            /usr/local/sbin/update-motd
        fi
    }
}

#===============================================================
#
#   Main
#
#===============================================================

# shell check source=/dev/null
hide_run_as_root=1 . /opt/AOK/tools/run_as_root.sh

[ -z "$d_aok_etc" ] && aok_this_is_dest_fs="Y" . /opt/AOK/tools/utils.sh

. /opt/AOK/tools/multi_use.sh

# shellcheck disable=SC1007
prog_name=$(basename "$0")

while [ -n "$1" ]; do
    case "$1" in
    -h | --help) show_help ;;
    -c | --configs) update_configs=1 ;;
    *)
        echo
        echo "ERROR: Bad param '$1'"
        echo
        show_help
        ;;
    esac
    shift
done

ensure_ish_or_chrooted ""

if fs_is_alpine; then
    distro_prefix="/opt/AOK/Alpine"
    distro_fam_prefix="/opt/AOK/Alpine"
elif fs_is_devuan; then
    distro_prefix="/opt/AOK/Devuan"
    distro_fam_prefix="/opt/AOK/FamDeb"
elif fs_is_debian; then
    distro_prefix="/opt/AOK/Debian"
    distro_fam_prefix="/opt/AOK/FamDeb"
elif fs_is_gentoo; then
    distro_prefix="/opt/AOK/Gentoo"
    distro_fam_prefix="/opt/AOK/Gentoo"
else
    error_msg "FS type not recognized"
fi

d_new_etc_opt_prefix="/etc/opt/AOK"

if [ "$update_configs" = "1" ]; then
    echo
    restore_configs
fi

general_upgrade
update_etc_opt_references
update_aok_release
verify_launch_cmd
obsolete_files
check_softlinks

# Double check that no new incompatiblities have been listed
msg_2 "Ensuring no incompatabilies are detected"
/usr/local/bin/check-env-compatible

cmd_post_update=/etc/opt/AOK/post-update.sh

[ -x "$cmd_post_update" ] && {
    msg_2 "Running $cmd_post_update"
    $cmd_post_update
}

echo
aok-versions
