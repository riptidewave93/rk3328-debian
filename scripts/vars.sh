#!/bin/bash

root_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"
build_path="${root_path}/BuildEnv"

# Docker image name
docker_tag=rk3328-builder:builder

# Supported Devices
supported_devices=(rk3328-nanopi-neo3 rk3328-nanopi-r2s)

# Toolchain
toolchain_url="https://developer.arm.com/-/media/Files/downloads/gnu/12.2.rel1/binrel/arm-gnu-toolchain-12.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz"
toolchain_filename="$(basename $toolchain_url)"
toolchain_bin_path="${toolchain_filename%.tar.xz}/bin"
toolchain_cross_compile="aarch64-none-linux-gnu-"

# Arm Trusted Firmware
atf_src="https://github.com/ARM-software/arm-trusted-firmware/archive/refs/heads/master.zip"
atf_filename="arm-trusted-firmware-master.zip"
atf_platform="rk3328"

# U-Boot
uboot_src="https://github.com/u-boot/u-boot/archive/refs/tags/v2024.04-rc3.zip"
uboot_filename="u-boot-2024.04-rc3.zip"
uboot_overlay_dir="u-boot"

# Kernel
kernel_src="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/snapshot/linux-6.7.y.tar.gz"
kernel_filename="linux-6.7.y.tar.gz"
kernel_config="rk3328_defconfig"
kernel_overlay_dir="kernel"

# Genimage
genimage_src="https://github.com/pengutronix/genimage/releases/download/v16/genimage-16.tar.xz"
genimage_filename="$(basename $genimage_src)"
genimage_repopath="${genimage_filename%.tar.xz}"

# Distro
distrib_name="debian"
deb_mirror="http://ftp.us.debian.org/debian"
deb_release="bookworm"
deb_arch="arm64"
fs_overlay_dir="filesystem"

debug_msg () {
    BLU='\033[0;32m'
    NC='\033[0m'
    printf "${BLU}${@}${NC}\n"
}

error_msg () {
    BLU='\033[0;31m'
    NC='\033[0m'
    printf "${BLU}${@}${NC}\n"
}