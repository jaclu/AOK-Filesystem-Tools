#!/bin/sh
# shellcheck disable=SC2034 # don't warn about unused variables
# This is sourced. Fake bang-path to help editors and linters
#
#  Part of https://github.com/jaclu/AOK-Filesystem-Tools
#
#  License: MIT
#
#  Copyright (c) 2023-2024: Jacob.Lundqvist@gmail.com
#
#  Common environment for aok_fs-save & aok_fs-replace
#

[ -z "$d_aok_etc" ] && . /opt/AOK/tools/utils.sh

d_aok_completed="$TMPDIR"/aok_completed
f_tar_tmp_save="$TMPDIR"/saving.tgz
d_aok_fs_save="$TMPDIR"/tmp_save
d_aok_fs_replace="$TMPDIR"/tmp_replace

#
#  Ensure env exists
#
mkdir -p "$d_aok_completed" || {
    error_msg "Failed to create: $d_aok_completed"
}
[ ! -d "$d_aok_completed" ] && {
    error_msg "d_aok_completed is not a folder: $d_aok_completed"
}

ensure_not_chrooted() {
    is_chroot_mounted "$1" && {
        error_msg "it seems a chroot is active at: $d_fs"
    }
}
