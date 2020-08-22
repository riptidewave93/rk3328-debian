# Recompile with:
# mkimage -C none -A arm -T script -d boot.cmd boot.scr

# Set local vars
setenv config_load_addr "0x44000000"
setenv kernel_comp_addr_r "0x05000000"
setenv ramdisk "initrd.img-KERNELVER"
setenv kernel "vmlinuz-KERNELVER"
setenv extra_cmdline "fsck.repair=yes panic=10"

# Import and load any custom settings
if test -e ${devtype} ${devnum}:${distro_bootpart} config.txt; then
	load ${devtype} ${devnum}:${distro_bootpart} ${config_load_addr} config.txt
	env import -t ${config_load_addr} ${filesize}
fi

# If this is first boot, save our env (Broke ATM)
if test ! -e ${devtype} ${devnum}:${distro_bootpart} uboot.env; then
	saveenv
fi

# Load FDT
load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} ${fdtfile}

# Set cmdline
setenv bootargs root=/dev/mmcblk0p5 rootfstype=ext4 rw rootwait earlyprintk ${extra_cmdline}

# Boot our image
load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} ${kernel}
setenv kernel_comp_size ${filesize}
load ${devtype} ${devnum}:${distro_bootpart} ${ramdisk_addr_r} ${ramdisk}
setenv ramdisk_size ${filesize}

# Boot the system
booti ${kernel_addr_r} ${ramdisk_addr_r}:${ramdisk_size} ${fdt_addr_r}
