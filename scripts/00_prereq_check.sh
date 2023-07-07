#!/bin/bash
set -e

# Source our common vars
scripts_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${scripts_path}/vars.sh

debug_msg "Starting 00_prereq_check.sh"

# Check for required utils
for bin in losetup docker wget sudo; do
    if ! which ${bin} > /dev/null; then
        error_msg "${bin} is missing! Exiting..."
        exit 1
    fi
done

# Make sure loop module is loaded
if [ ! -d /sys/module/loop ]; then
    error_msg "Loop module isn't loaded into the kernel! This is REQUIRED! Exiting..."
    exit 1
fi

debug_msg "Finished 00_prereq_check.sh"
