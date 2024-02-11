**WARNING - my UART adapter broke and this is still untested.**
**Until a new one arrives and I find some time for testing, this is for informational purposes only.**

Create an image of Arch Linux to write onto a SD flash card or eMMC flash chip for the Star64 SBC.
Try to do that with as 'upstream' as possible.
In principle, it should be possible to create images for other distribution's as well.

Run `make` to create the image and use dd, Etcher, or so to install it.
Supplying a block device as as `IMG_NAME` (e.g. `make "IMG_NAME=/dev/mmcblkX"`) will cause the image to be written directly to the block device.
This allows the root partition to use all available space - and the amount of writes is reduced to a minimum because gaps don't have to be filled.

For convenience, `DISK_DEV=/dev/mmcblkX make fit` can be used to flash an existing image and automatically resize the system partition.

# requirements

- subuid/subgid entries for the user running `make`
  - only the first one is used
  - range needs to be big enough to hold all files from the base file system
  - 1000 should be enough but best be generous if possible (e.g. 10000) because tar doesn't stop (it only warns)
- qemu-riscv64-static and the respective binfmt rules (to allow running riscv64 programs in the chroot)
- enough RAM to hold the rootfs
- riscv64-linux-gnu-gcc

# sources

- U-Boot SPL with OpenSBI
- U-Boot payload (reads extlinux.conf)
- Felix Yan's Arch Linux port for RISC-V (https://archriscv.felixc.at/)

# customization

The filesystem can be altered by adding customization scripts in rootfs-hook.d/.
Nothing stops you from calling `sh` from there and doing stuff interactively.
Remember to add the executable bit.

`.env.rootfs-customization` can be used to pass environment variables to the hooks.
The pre-existing scripts use these:

```
ROOT_PW
NO_ROOT_PW
ROOT_SSH_KEY
INSTALL_OPENSSH
KEEP_SSH_KBD_PW
```

# other ideas

- method to install tow-boot or EDK2 XSPI NOR
  - makes this repo obsolete
- boot using EFI
