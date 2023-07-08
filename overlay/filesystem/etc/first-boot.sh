#!/bin/bash
set -e

# Generate new SSH keys for the host
ssh-keygen -q -f "/etc/ssh/ssh_host_rsa_key" -N '' -t rsa
ssh-keygen -q -f "/etc/ssh/ssh_host_ecdsa_key" -N '' -t ecdsa
ssh-keygen -q -f "/etc/ssh/ssh_host_ed25519_key" -N '' -t ed25519

# Get our partuuid so we can map what MMC we are on
rootpartuuid=$(cat /proc/cmdline | sed 's| |\n|g' | sed -n 's/^root=PARTUUID=//p')

# For every MMC disk we have, get our Disk Identifier
for mmc in $(ls /dev/mmcblk[00-99]); do
  if [[ "$(fdisk -l ${mmc} | grep "Disk identifier:" | awk '{print $3}')" == "0x${rootpartuuid%???}" ]]; then
    bootedmmc="${mmc}p2"
    break
  fi
done

# If we didn't find our disk, bomb out!
if [ -z ${bootedmmc+x} ]; then
  echo "ERROR, unable to determine root mmc partition! Skipping resize..."
else
  # Get start offset of rootfs partition
  rootfs_start=$(fdisk -l ${bootedmmc%??} | grep ${bootedmmc} | awk '{ print $2 }')

  # Resize root disk
  fdisk ${bootedmmc%??} << DISK
d
2
n
p
2
${rootfs_start}

w
DISK

  # Add our mount for boot and mount it if it doesn't exist
  if ! grep -q "/boot" /etc/fstab; then
    echo "PARTUUID=${rootpartuuid%??}01  /boot           vfat    defaults        0       1" >> /etc/fstab
  fi
  mount -a

  # Update kernel partition mapping & kickoff resize
  partprobe
  resize2fs ${bootedmmc%??}p2
  sync
fi

# Probe for any added modules
depmod -a

# Fixup initramfs for fsck on boot to work
KERN_VERSION=$(find /lib/modules/ -maxdepth 1 | sort | tail -1 | xargs basename )
update-initramfs -u -k ${KERN_VERSION}
if [ -f /boot/initramfs.cpio.gz ]; then
  rm /boot/initramfs.cpio.gz
fi

# If we are here, we can safely move off of boot.scr to extlinux once our dtb is set
export UBOOT_DTB_NAME=$(fw_printenv -n fdtfile)
sed -i "s|UBOOTDTBNAMEGOESHERE|${UBOOT_DTB_NAME}|g" /etc/default/u-boot.rk3328
mv /etc/default/u-boot.rk3328 /etc/default/u-boot
u-boot-update

# And were done!
systemctl disable first-boot.service
rm -f /etc/systemd/system/first-boot.service
rm -f $0
