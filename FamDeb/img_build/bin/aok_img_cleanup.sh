#!/bin/sh
#
#  Part of https://github.com/emkey1/AOK-Filesystem-Tools
#
#  License: MIT
#
#  Copyright (c) 2024: Jacob.Lundqvist@gmail.com
#
#  Cleans up the FS AOK uses to generate Devuan imgs
#

d_here="$(dirname "$0")"

. /opt/AOK/tools/utils.sh
# shellcheck source=/dev/null
. "$d_here"/img_build_utils.sh

health_check
clear_log_tmp
update_aok_fs_releae
clear_AOK

echo "After you exit the chroot"
echo "1. Clear out tmp using something like:"
echo "   rm -rf [mountpoint]/tmp/*"
echo
echo "2. Depending on privacy concerns, since this image is typically"
echo "   made available for public download, consider to check"
echo "   [mountpont]/root/.bash_history"
echo