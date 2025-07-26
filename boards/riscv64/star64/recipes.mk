$(DEV_OR_IMG): $(ROOTFS_IMG) $(UBOOT_ITB) $(UBOOT_SPL) uboot-star64
	ROOTFS_IMG=$(ROOTFS_IMG) \
		UBOOT_ITB=$(UBOOT_ITB) UBOOT_SPL=$(UBOOT_SPL) \
		./boards/$(ARCH)/$(DEVICE)/compile_image $@

.PHONY: opensbi
opensbi: $(OPENSBI_BIN)

$(OPENSBI_BIN): | $(OPENSBI_CLONE)
	# TODO update?
	#git -C $(OPENSBI_CLONE) ls-remote --refs --sort="version:refname" --tags $(OPENSBI_GIT) | cut -d/ -f3-|tail -n1
	make -C $(OPENSBI_CLONE) PLATFORM=generic FW_TEXT_START=0x40000000 FW_OPTIONS=0 FW_DYNAMIC=y

$(OPENSBI_CLONE): | $(BUILD_DIR)
	git clone $(OPENSBI_GIT) $(OPENSBI_CLONE)

$(STAR64_EXTLINUX_PKG): $(ROOTFS_UUID)
	cd packages/uboot-extlinux-conf-hook ;\
		CARCH=riscv64 makepkg -f ROOTFS_UUID=$(shell cat $(ROOTFS_UUID))
	# TODO pass in version from make as well? could then be used to construct filename
	cp packages/uboot-extlinux-conf-hook/uboot-extlinux-conf-hook-0.1-1-riscv64.pkg.tar.zst $@

.PHONY: target_device_clean
target_device_clean:
	[ ! -d $(OPENSBI_CLONE) ] || make -C $(OPENSBI_CLONE) clean

.PHONY: uboot-star64
uboot-star64: $(OPENSBI_BIN)
	make -C $(UBOOT_CLONE) \
		OPENSBI=$(abspath $(OPENSBI_BIN))
