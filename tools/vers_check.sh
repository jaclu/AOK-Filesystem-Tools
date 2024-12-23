#!/bin/sh
# This is sourced. Fake bang-path to help editors and linters
#
#  Part of https://github.com/jaclu/AOK-Filesystem-Tools
#
#  License: MIT
#
#  Copyright (c) 2024: Jacob.Lundqvist@gmail.com
#
#  Should normally be sourced, if run as a standalone, will do self tests
#  Provides:
#       min_release() - returns true if first param is <= running version of Alpine
#       current_alpine_release - running alpine release
#

if [ -f /etc/os-release ]; then
    os_release=/etc/os-release
elif [ -f /usr/lib/os-release ]; then
    os_release=/usr/lib/os-release
fi
if [ -m "$os_release" ]; then
    current_alpine_release="$(cat "$os_release" | grep VERSION_ID | cut -d= -f2)"
else
    # not changed by Alpine release upgrades, so least reliable
    current_alpine_release="$(cat /etc/alpine-release)"
fi

min_release() {
    # returns true if param1 <= ref version
    version1="$1"
    version2="${2:-$current_alpine_release}"

    echo "$version1" | grep -q '\.' || version1="${version1}.0"
    echo "$version2" | grep -q '\.' || version2="${version2}.0"

    # Split version strings into components (major, minor, patch)
    major1=$(echo "$version1" | cut -d'.' -f1)
    minor1=$(echo "$version1" | cut -d'.' -f2)
    [ -z "$minor1" ] && minor1=0
    patch1=$(echo "$version1" | cut -d'.' -f3)
    [ -z "$patch1" ] && patch1=0

    major2=$(echo "$version2" | cut -d'.' -f1)
    [ -z "$minor2" ] && minor2=0
    minor2=$(echo "$version2" | cut -d'.' -f2)
    patch2=$(echo "$version2" | cut -d'.' -f3)
    [ -z "$patch2" ] && patch2=0

    # echo "# comparing [$version1] [$version2]"
    # echo "# split up [$major1][$minor1][$patch1] and [$major2][$minor2][$patch2]"

    # Compare major version
    if [ "$major1" -lt "$major2" ]; then
        return 0 # version1 is greater
    elif [ "$major1" -gt "$major2" ]; then
        return 1 # version2 is greater
    fi

    # Compare minor version
    if [ "$minor1" -lt "$minor2" ]; then
        return 0 # version1 is greater
    elif [ "$minor1" -gt "$minor2" ]; then
        return 1 # version2 is greater
    fi

    # Compare patch version
    if [ "$patch1" -lt "$patch2" ]; then
        return 0 # version1 is greater
    elif [ "$patch1" -gt "$patch2" ]; then
        return 1 # version2 is greater
    fi

    # If all components are equal
    return 0 # versions are equal
}

_vers_check_verify() {
    rslt_exp="$1"
    v_ref="$2"
    v_comp="$3"

    min_release "$v_ref" "$v_comp" && rslt_actual=0 || rslt_actual=1
    [ "$rslt_actual" = "$rslt_exp" ] || {
        echo "Failed: $v_ref <= $v_comp should be $rslt_exp - was $rslt_actual"
        exit 1
    }
}

_vers_check_test() {
    echo
    echo "=====   Testing min_release   ====="

    # basic number
    _vers_check_verify 0 3 3
    _vers_check_verify 0 3 4
    _vers_check_verify 1 3 2

    # two digits first
    ref="2.1"
    _vers_check_verify 0 "$ref" "$ref"
    _vers_check_verify 0 "$ref" 2.1.0
    _vers_check_verify 0 "$ref" 2.1.2
    _vers_check_verify 0 "$ref" 2.2
    _vers_check_verify 0 "$ref" 2.2.1
    _vers_check_verify 0 "$ref" 3
    _vers_check_verify 0 "$ref" 3.1
    _vers_check_verify 0 "$ref" 3.0.1
    _vers_check_verify 1 "$ref" 1
    _vers_check_verify 1 "$ref" 2
    _vers_check_verify 1 "$ref" 2.0
    _vers_check_verify 1 "$ref" 2.0.1

    # three digits first
    ref="2.3.4"
    _vers_check_verify 0 "$ref" 3
    _vers_check_verify 0 "$ref" 2.4
    _vers_check_verify 0 "$ref" 2.3.5
    _vers_check_verify 0 "$ref" "$ref"
    _vers_check_verify 1 "$ref" 2
    _vers_check_verify 1 "$ref" 2.3
    _vers_check_verify 1 "$ref" 2.3.3

    # three digits second
    ref="2.3.4"
    _vers_check_verify 0 2 "$ref"
    _vers_check_verify 0 2.3 "$ref"
    _vers_check_verify 0 2.3.3 "$ref"
    _vers_check_verify 1 3 "$ref"
    _vers_check_verify 1 3.1 "$ref"
    _vers_check_verify 1 3.1.2 "$ref"

    # numbers > 9
    _vers_check_verify 1 11 10
    _vers_check_verify 1 11 10.1
    _vers_check_verify 0 11 11
    _vers_check_verify 0 11 11.1
    _vers_check_verify 0 11 12

    # current version (assumed to be >= 3.14)
    _vers_check_verify 0 2
    _vers_check_verify 0 3
    _vers_check_verify 0 3.13

    echo "All tests successfull!"
}

#===============================================================
#
#   Main
#
#===============================================================
#
#  Run the tests by calling this directly
#
[ "$(basename "$0")" = "vers_check.sh" ] && _vers_check_test
unset -f _vers_check_verify _vers_check_test
