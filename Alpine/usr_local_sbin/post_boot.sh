#!/bin/sh
#
#  Part of https://github.com/emkey1/AOK-Filesystem-Tools
#
#  License: MIT
#
#  Copyright (c) 2023: Jacob.Lundqvist@gmail.com
#
#  Intended usage is for small systems where a cron might not be running and or
#  needing to do some sanity checks after booting.
#
#  Trigger this in /etc/inittab by adding a line:
#
#  ::once:/usr/local/bin/post_boot.sh
#
#  In the case of AOK
#    * there are some first-run tasks that need to be done
#    * services sometimes fail to start by init, restarting them here
#      tends to help
#
#  Global shellcheck settings:
# shellcheck disable=SC2154

post_boot_log=/var/log/post_boot.log

respawn_it() {
    tmp_log_file="/tmp/post_boot-$$"

    $0 will_run >"$tmp_log_file" 2>&1

    # only keep tmp log if not empty
    log_size="$(/bin/ls -s "$tmp_log_file" | awk '{ print $1 }')"
    if [ "$log_size" -ne 0 ]; then
        echo "---  $(date) ($$)  ---" >>"$post_boot_log"
        cat "$tmp_log_file" >>"$post_boot_log"
    fi
    rm "$tmp_log_file"
    # shellcheck disable=SC2317
    exit 0
}

#
#  If run with no parameters, respawn with output going to $post_boot_log,
#  all to be inittab friendly.
#
if [ -z "$1" ]; then
    echo "with no param this is re-spawned, logging to: $post_boot_log:"
    respawn_it
    # shellcheck disable=SC2317
    exit 0
fi

#
#  Restart all services not in started state, should not be needed normally
#  but here we are, and if they are already running, nothing will happen.
#
/usr/local/bin/do_fix_services
