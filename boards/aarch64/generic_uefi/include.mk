USE_EFI = 1

ALARM_EFI_PKG = $(BUILD_DIR)/alarm-efi-install.pkg.tar.zst
export ALARM_EFI_PKG

ROOTFS_DEPS ?= $(ALARM_EFI_PKG)
