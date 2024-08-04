#!/bin/sh
#
#  Part of https://github.com/jaclu/AOK-Filesystem-Tools
#
#  License: MIT
#
#  Copyright (c) 2023-2024: Jacob.Lundqvist@gmail.com
#
#  Reports network status
#

if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
    if ping -c 2 amazon.com >/dev/null 2>&1; then
        echo "Connected to the Internet and DNS is resolving!"
    else
        echo "***  DNS does not seem to resolve!"
    fi
else
    echo "***  Not able to access the Internet!"
fi
echo
