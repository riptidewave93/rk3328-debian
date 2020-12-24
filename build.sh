#!/bin/bash

# Supported boards
supported_devices=(nanopi-neo3 nanopi-r2s)

# Date format, used in the image file name
mydate=`date +%Y%m%d-%H%M`

# Size of the image and boot partitions
imgsize="2G"
bootsize="256M"

# Location of the build environment, where the image will be mounted during build
ourpath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
buildenv="$ourpath/BuildEnv"

# folders in the buildenv to be mounted, one for rootfs, one for /boot
# Recommend that you don't change these!
rootfs="${buildenv}/rootfs"
bootfs="${rootfs}/boot"

# Compiler settings
linaro_release="7.5-2019.12"
linaro_full_version="7.5.0-2019.12"

# Arm Trusted Firmware settings
atf_repo="https://github.com/ARM-software/arm-trusted-firmware.git"
atf_branch="master"
atf_platform="rk3328"

# U-Boot settings
uboot_repo="https://github.com/u-boot/u-boot.git"
uboot_branch="v2021.01-rc4"
uboot_overlay_dir="u-boot"

# Kernel settings
kernel_repo="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
kernel_branch="linux-5.10.y"
kernel_config="rk3328_defconfig"
kernel_overlay_dir="kernel"

# Distro settings
distrib_name="debian"
deb_mirror="https://mirrors.kernel.org/debian/"
deb_release="buster"
deb_arch="arm64"
fs_overlay_dir="filesystem"

##############################
# No need to edit under this #
##############################

# Basic function we use to make sure we did not fail
runtest() {
  if [ $1 -ne 0 ]; then
    echo "Build Failed!"
    rm -rf "$ourpath/.build" "$ourpath/requires" "$ourpath/output" "$ourpath/BuildEnv"
    exit 1
  fi
}

# Check to make sure this is ran by root
if [ $EUID -ne 0 ]; then
  echo "DEB-BUILDER: this tool must be run as root"
  exit 1
fi

# Are we asking for a clean? If so, reset the env
if [[ "$1" == "clean" ]]; then
  echo "DEB-BUILDER: Cleaning build environment..."
  rm -rf "$ourpath/BuildEnv" "$ourpath/.build" "$ourpath/requires" "$ourpath/output"
  echo "DEB-BUILDER: Cleaning complete!"
  exit 0
fi

# make sure no builds are in process (which should never be an issue)
if [ -e ./.build ]; then
	echo "DEB-BUILDER: Build already in process, aborting"
	exit 1
else
	touch ./.build
fi

echo "DEB-BUILDER: Building $distrib_name Image"

# Start by making our build dir
mkdir -p $buildenv/toolchain
cd $buildenv

# Setup our build toolchain for this
echo "DEB-BUILDER: Setting up Toolchain"
if [ ! -e $ourpath/downloads/gcc-linaro-$linaro_full_version-x86_64_aarch64-linux-gnu.tar.xz ]; then
	mkdir $ourpath/downloads
	wget https://releases.linaro.org/components/toolchain/binaries/$linaro_release/aarch64-linux-gnu/gcc-linaro-$linaro_full_version-x86_64_aarch64-linux-gnu.tar.xz -P $ourpath/downloads
fi
tar xf $ourpath/downloads/gcc-linaro-$linaro_full_version-x86_64_aarch64-linux-gnu.tar.xz -C $buildenv/toolchain
export PATH=$buildenv/toolchain/gcc-linaro-$linaro_full_version-x86_64_aarch64-linux-gnu/bin:$PATH
export GCC_COLORS=auto
export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64

# Build our dependencies
echo "DEB-BUILDER: Building Dependencies"
mkdir -p $ourpath/requires
mkdir -p $buildenv/git
cd $buildenv/git

# Build ARM Trusted Firmware
git clone $atf_repo --depth 1 -b $atf_branch
cd arm-trusted-firmware
make PLAT=$atf_platform bl31
runtest $?
export BL31=$buildenv/git/arm-trusted-firmware/build/$atf_platform/release/bl31/bl31.elf
cd $buildenv/git

# Build U-Boot
git clone $uboot_repo --depth 1 -b $uboot_branch ./u-boot
cd u-boot
# If we have patches, apply them
if [[ -d $ourpath/patches/u-boot/ ]]; then
	for file in $ourpath/patches/u-boot/*.patch; do
		echo "Applying u-boot patch $file"
		git am $file
    runtest $?
	done
fi
# Apply overlay if it exists
if [[ -d $ourpath/overlay/$uboot_overlay_dir/ ]]; then
	echo "Applying $uboot_overlay_dir overlay"
	cp -R $ourpath/overlay/$uboot_overlay_dir/* ./
fi
# Each board gets it's own u-boot, so build each at a time
for board in "${supported_devices[@]}"; do
	cfg=$board
	cfg+="_defconfig"
	make distclean
	make $cfg
	make -j`nproc`
  runtest $?
  cp ./u-boot-rockchip.bin $ourpath/requires/$board.uboot
done
cd $buildenv/git

# Build the Linux Kernel
mkdir linux-build && cd ./linux-build
git clone $kernel_repo --depth 1 -b $kernel_branch ./linux
cd linux
# If we have patches, apply them
if [[ -d $ourpath/patches/kernel/ ]]; then
	for file in $ourpath/patches/kernel/*.patch; do
		echo "Applying kernel patch $file"
		git am $file
    runtest $?
	done
fi
# Apply overlay if it exists
if [[ -d $ourpath/overlay/$kernel_overlay_dir/ ]]; then
	echo "Applying $kernel_overlay_dir overlay"
	cp -R $ourpath/overlay/$kernel_overlay_dir/* ./
fi

# Build as normal
make $kernel_config
make -j`nproc` deb-pkg dtbs
runtest $?

# Copy over our needed files
for i in "${supported_devices[@]}"; do
	cp arch/arm64/boot/dts/rockchip/rk3328-$i.dtb $ourpath/requires/
done
cd "$buildenv/git/linux-build"
cp linux-*.deb $ourpath/requires/
# remove debug
rm $ourpath/requires/linux-image-*-dbg_*.deb

# Before we start up, make sure our required files exist
for file in "${supported_devices[@]}"; do
	if [[ ! -e "$ourpath/requires/rk3328-$file.dtb" ]]; then
		echo "DEB-BUILDER: Error, required file './requires/rk3328-$file.dtb' is missing!"
		rm $ourpath/.build
		exit 1
	fi
	if [[ ! -e "$ourpath/requires/$file.uboot" ]]; then
		echo "DEB-BUILDER: Error, required file './requires/$file.uboot' is missing!"
		rm $ourpath/.build
		exit 1
	fi
done

# Create the buildenv folder, and image file
echo "DEB-BUILDER: Creating Image file"
image="${buildenv}/headless_${distrib_name}_${deb_release}_${deb_arch}_${mydate}.img"
fallocate -l $imgsize "$image"
loopback=`losetup -f --show $image`
echo "DEB-BUILDER: Image $image created and mounted as $loopback"
# Format the image file partitions
echo "DEB-BUILDER: Setting up GPT/Partitions"
sgdisk -o -a 64 -n 1:64:8063 -t 1:0700 -c 1:loader1 \
  -n 2:16384:24575 -t 2:0700 -c 2:loader2 \
  -n 3:24576:32767 -t 3:0700 -c 3:trust \
  -n 4:32768:${bootsize} -t 4:0700 -c 4:boot \
  -A 4:set:2 \
  -n 5:0:0 -t 5:8305 -c 5:rootfs $loopback

# Some systems need partprobe to run before we can fdisk the device
partprobe

# Mount the loopback device so we can modify the image, format the partitions, and mount/cd into rootfs
mapped_loopback=`kpartx -va $loopback | sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1`
bootp="/dev/mapper/${mapped_loopback}p4"
rootp="/dev/mapper/${mapped_loopback}p5"
echo "DEB-BUILDER: Formatting Partitions"
mkfs.vfat $bootp -n boot
mkfs.ext4 $rootp -L rootfs
mkdir -p $rootfs
mount $rootp $rootfs
cd $rootfs

#  start the debootstrap of the system
echo "DEB-BUILDER: Mounted partitions, debootstraping..."
debootstrap --no-check-gpg --foreign --arch $deb_arch $deb_release $rootfs $deb_mirror
cp /usr/bin/qemu-aarch64-static usr/bin/
LANG=C chroot $rootfs /debootstrap/debootstrap --second-stage

# Mount the boot partition
mount -t vfat $bootp $bootfs

# Now that things are mounted, copy over an overlay if it exists
if [[ -d $ourpath/overlay/$fs_overlay_dir/ ]]; then
	echo "Applying $fs_overlay_dir overlay"
	cp -R $ourpath/overlay/$fs_overlay_dir/* ./
fi

# Start adding content to the system files
echo "DEB-BUILDER: Setting up device specific tweaks"

# apt mirrors
echo "deb $deb_mirror $deb_release main contrib non-free
deb-src $deb_mirror $deb_release main contrib non-free
# Backports for firmware
deb $deb_mirror buster-backports main non-free
" > etc/apt/sources.list

# Mounts
echo "proc            /proc           proc    defaults        0       0" > etc/fstab

# Hostname
echo "${distrib_name}" > etc/hostname
echo "127.0.1.1	${distrib_name}" >> etc/host

# Networking
echo "auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp
iface eth0 inet6 dhcp
" > etc/network/interfaces

# uboot env tools
echo "
# MTD device name       Device offset   Env. size       Flash sector size
/boot/uboot.env         0x0             0x20000         0x2000
" > etc/fw_env.config

# Console settings
echo "console-common	console-data/keymap/policy	select	Select keymap from full list
console-common	console-data/keymap/full	select	us
" > debconf.set

# Third Stage Setup Script (most of the setup process)
cat << EOF > third-stage
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
debconf-set-selections /debconf.set
rm -f /debconf.set
echo 'deb http://deb.debian.org/debian/ unstable main' > /etc/apt/sources.list.d/debian-unstable.list
printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' > /etc/apt/preferences.d/limit-unstable
apt-get update
apt-get -y install git binutils ca-certificates e2fsprogs ntp parted curl haveged \
locales console-common openssh-server less vim net-tools initramfs-tools \
wireguard-tools u-boot-tools locales wget
apt-get -y -t buster-backports install firmware-realtek
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
locale-gen en_US.UTF-8
echo "root:debian" | chpasswd
rm -f /etc/udev/rules.d/70-persistent-net.rules
sed -i 's|#PermitRootLogin prohibit-password|PermitRootLogin yes|g' /etc/ssh/sshd_config
echo 'HWCLOCKACCESS=yes' >> /etc/default/hwclock
echo 'RAMTMP=yes' >> /etc/default/tmpfs
rm -f third-stage
EOF
chmod +x third-stage
LANG=C chroot $rootfs /third-stage

# Setup our boot partition so we can actually boot
cp -R $ourpath/requires root
cat << EOF > forth-stage
#!/bin/bash
dpkg -i /root/requires/linux-*.deb
mkdir -p /boot/rockchip
mv /root/requires/*.dtb /boot/rockchip/
KernVer=\$(ls -t /boot | grep vmlinuz | head -1 | sed 's|vmlinuz-||')
sed -i "s|KERNELVER|\${KernVer}|g" /boot/boot.cmd
mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
rm -rf /root/requires
rm -f forth-stage
EOF
chmod +x forth-stage
LANG=C chroot $rootfs /forth-stage
echo "DEB-BUILDER: Cleaning up build space/image"

# Cleanup Script
echo "#!/bin/bash
update-rc.d ssh remove
apt-get autoclean
apt-get --purge -y autoremove
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
service ntp stop
rm -rf /boot.bak
rm -f cleanup
" > cleanup
chmod +x cleanup
LANG=C chroot $rootfs /cleanup

# startup script to generate new ssh host keys
rm -f etc/ssh/ssh_host_*
echo "DEB-BUILDER: Deleted SSH Host Keys. Will re-generate at first boot by user"

# Make sure first boot is setup
chmod a+x etc/init.d/first_boot
LANG=C chroot $rootfs update-rc.d first_boot defaults
LANG=C chroot $rootfs update-rc.d first_boot enable

# Lets cd back
cd $buildenv && cd ..

# Unmount some partitions
echo "DEB-BUILDER: Unmounting Partitions"
umount $bootp
umount $rootp
kpartx -d /dev/$mapped_loopback

# Properly terminate the loopback devices
echo "DEB-BUILDER: Finished making the image $image"
dmsetup remove_all
losetup -D

# For each board, generate our images
echo "DEB-BUILDER: Copying image per board and installing u-boot"
savedir="$ourpath/output/$mydate"
mkdir -p $savedir
mv ${image} $savedir/headless_${distrib_name}_${deb_release}_${deb_arch}_${mydate}.img
for board in "${supported_devices[@]}"; do
	cp $savedir/headless_${distrib_name}_${deb_release}_${deb_arch}_${mydate}.img $savedir/${board}_headless_${distrib_name}_${deb_release}_${deb_arch}_${mydate}.img
	# Install OUR u-boot
	dd if=$ourpath/requires/$board.uboot of=$savedir/${board}_headless_${distrib_name}_${deb_release}_${deb_arch}_${mydate}.img seek=64 conv=notrunc
	# Compress the specific image
	gzip $savedir/${board}_headless_${distrib_name}_${deb_release}_${deb_arch}_${mydate}.img
done

# Move image out of builddir, as buildscript will delete it
echo "DEB-BUILDER: Moving things around"
mkdir -p $savedir/kernel
mv $ourpath/requires/linux-*.deb $savedir/kernel
mv $ourpath/requires/*.dtb $savedir/kernel
mkdir -p $savedir/u-boot
mv $ourpath/requires/*.uboot $savedir/u-boot
cd $ourpath

echo "DEB-BUILDER: Cleaning Up"
rm $savedir/headless_${distrib_name}_${deb_release}_${deb_arch}_${mydate}.img
rm $ourpath/.build
rm -r $ourpath/requires
rm -r $buildenv
echo "DEB-BUILDER: Finished!"
exit 0
