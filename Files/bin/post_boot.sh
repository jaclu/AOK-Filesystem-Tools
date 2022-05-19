#!/bin/sh
#
#  Copyright (c) 2022: Jacob.Lundqvist@gmail.com
#  License: MIT
#
#   Version: 1.0.0  2022-05-06
#
#  Intended usage is for cronless systems, needing to do some sanity checks
#  after booting. Trigger this in /etc/inittab by adding a line:
#
#  ::wait:/usr/local/bin/post_boot.sh
#
#  Before starting /sbin/openrc or similar
#


#
#  If run with no params, spawn another instance in the background and exit
#  in order to be inittab friendly
#
if [ "$1" = "" ]; then
    $0 will_run &
    exit 0
fi

#
# Give the system time to complete it's startup
#
sleep 10


#
#  Do all sanity checks needed...
#

/etc/init.d/sshd restart
/etc/init.d/runbg restart
/etc/init.d/dcron restart
