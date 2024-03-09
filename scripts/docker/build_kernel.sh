#!/bin/bash
set -e

scripts_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"
. ${scripts_path}/vars.sh

# Make our temp builddir outside of the world of mounts for SPEEDS
kernel_builddir=$(mktemp -d)
tar -xzf ${root_path}/downloads/${kernel_filename} -C ${kernel_builddir}

# Exports baby
export PATH=${build_path}/toolchain/${toolchain_bin_path}:${PATH}
export GCC_COLORS=auto
export CROSS_COMPILE=${toolchain_cross_compile}
export ARCH=arm64

# Here we go
cd ${kernel_builddir}/${kernel_filename%.tar.gz}

# If we have patches, apply them
if [[ -d ${root_path}/patches/kernel/ ]]; then
    for file in ${root_path}/patches/kernel/*.patch; do
        echo "Applying kernel patch ${file}"
        patch -p1 < ${file}
    done
fi

# Apply overlay if it exists
if [[ -d ${root_path}/overlay/${kernel_overlay_dir}/ ]]; then
    echo "Applying ${kernel_overlay_dir} overlay"
    cp -R ${root_path}/overlay/${kernel_overlay_dir}/* ./
fi

# Build as normal, with our extra version set to a timestamp
make ${kernel_config}
#make menuconfig
make -j`getconf _NPROCESSORS_ONLN` EXTRAVERSION=-$(date +%Y%m%d-%H%M%S) bindeb-pkg dtbs

# Save our config
mkdir -p ${build_path}/kernel
make savedefconfig
mv defconfig ${build_path}/kernel/kernel_config

# Get our kernel version (fully)
KERNEL_VERSION=$(ls ${kernel_builddir}/linux-headers-*.deb | awk -F- '{ print $3"-"$6"-"$7 }')

# Now build our deb for the dtb's
mkdir -p ${build_path}/kernel/linux-dtbs-${KERNEL_VERSION}/boot/dtb-${KERNEL_VERSION}/rockchip
mv ./scripts/dtb-deb/DEBIAN ${build_path}/kernel/linux-dtbs-${KERNEL_VERSION}/
sed -i "s|KERNELVERSION|${KERNEL_VERSION}|g" ${build_path}/kernel/linux-dtbs-${KERNEL_VERSION}/DEBIAN/control
sed -i "s|KERNELVERSION|${KERNEL_VERSION}|g" ${build_path}/kernel/linux-dtbs-${KERNEL_VERSION}/DEBIAN/conffiles
for i in "${supported_devices[@]}"; do
	cp arch/arm64/boot/dts/rockchip/${i}.dtb ${build_path}/kernel/linux-dtbs-${KERNEL_VERSION}/boot/dtb-${KERNEL_VERSION}/rockchip
done
cd ${build_path}/kernel
dpkg-deb --root-owner-group --build linux-dtbs-${KERNEL_VERSION}
rm -rf ${build_path}/kernel/linux-dtbs-${KERNEL_VERSION}

# Move our debs to the kernel dir
mv ${kernel_builddir}/linux-*.deb ${build_path}/kernel
