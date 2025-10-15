$(DEV_OR_IMG): $(ROOTFS_IMG) $(EFI_IMG)
	ROOTFS_IMG=$(ROOTFS_IMG) \
		EFI_IMG=$(EFI_IMG) \
		./boards/$(ARCH)/$(DEVICE)/compile_image $@

# TODO
$(EFI_IMG):
	# 512 MB
	dd if=/dev/zero of=$@ bs=4096 count=$$(( 512 * 256 ))
	# now done in setup_rootfs
	#mkfs.vfat -i $(subst -,,$(EFI_UUID)) -F 32 $@

# TODO
$(ALARM_EFI_PKG): $(ROOTFS_UUID)
	cd packages/alarm-efi-install ;\
		CARCH=aarch64 makepkg -f
	# TODO pass in version from make as well? could then be used to construct filename
	cp packages/alarm-efi-install/alarm-efi-install-0.1-1-aarch64.pkg.tar.zst $@

# TODO get rid off this?
.PHONY: target_device_clean
target_device_clean:
