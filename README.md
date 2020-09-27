# rk3328-debian

Build script to build a Debian 10 image for FriendlyELEC NanoPi RK3328 based boards, as well as all dependencies. This includes the following:

- Mainline Linux Kernel - [linux-5.8.y](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/log/?h=linux-5.8.y)
  - Wireguard Mainline
- Arm Trusted Firmware - [arm-trusted-firmware/master branch](https://github.com/ARM-software/arm-trusted-firmware/tree/master)
- Mainline U-Boot - [v2020.10-rc5](https://github.com/u-boot/u-boot/tree/v2020.10-rc5)

Note that there are patches/modifications applied to the kernel and u-boot. The changes made can be seen in the `./patches` and `./overlay` directories. Also, a `./downloads` directory is generated to store a copy of the toolchain during the first build.

## Supported Boards
Currently images for the following devices are generated:
* FriendlyELEC NanoPi Neo3

## Requirements

- The following packages on your Debian/Ubuntu build host: `bc binfmt-support build-essential debootstrap device-tree-compiler dosfstools fakeroot git kpartx libsdl2-dev libssl-dev lvm2 parted python-dev python3-dev qemu qemu-user-static swig wget`

## Usage
- Just run `sudo ./build.sh`.
- Completed builds output to `./output`
- To cleanup and clear all builds, run `sudo ./build.sh clean`

## Flashing
- Take your completed image from `./output` and extract it with gunzip
- Flash directly to an SD card. Example: `dd if=./neo3*.img of=/dev/mmcblk0 bs=4M conv=fdatasync`

## To Do
* Neo3 Fixes:
  * Fixup reboot hang
* Add support for more boards (ex R2S)

## Notes
- This is a pet project that can change rapidly. Production use is not advised. Please only proceed if you know what you are doing!
