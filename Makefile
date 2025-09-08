TARGET ?= riscv64,star64
export TARGET

comma = ,
ARCH = $(firstword $(subst $(comma), ,$(TARGET)))
DEVICE = $(lastword $(subst $(comma), ,$(TARGET)))
export DEVICE

BUILD_DIR = build
DL_DIR = dl

BASE_ROOTFS_TAR = $(DL_DIR)/base_rootfs_$(ARCH).tar.zst

DEV_OR_IMG ?= $(BUILD_DIR)/$(TARGET).img

# TODO optional
LINUX_PKG = $(DL_DIR)/linux-$(ARCH).pkg.tar.zst

PACMAN_CACHE_DIR = $(DL_DIR)/pacman_cache-$(ARCH)/
PACMAN_CACHE_SUBDIRS = $(foreach dir,pkg sync,$(PACMAN_CACHE_DIR)/$(dir))

REPO_DB = $(DL_DIR)/core_$(ARCH).db.tar.gz
REPO_DB_URL = $(ARCH_LINUX_MIRROR)$(ARCH_LINUX_MIRROR_BASE)/core/core.db.tar.gz

ROOTFS_IMG = $(BUILD_DIR)/rootfs-$(TARGET).img
ROOTFS_BUILD_DIR = $(BUILD_DIR)/rootfs-$(TARGET)
ROOTFS_UUID = $(BUILD_DIR)/rootfs-$(TARGET).uuid

ROOTFS_WIGGLEROOM_MB ?= 256
export ROOTFS_WIGGLEROOM_MB

UBOOT_CLONE = $(BUILD_DIR)/u-boot
UBOOT_GIT = https://github.com/u-boot/u-boot.git
UBOOT_ITB = $(UBOOT_CLONE)/u-boot.itb
UBOOT_SPL = $(UBOOT_CLONE)/spl/u-boot-spl.bin.normal.out

ROOTFS_DEPS += $(BASE_ROOTFS_TAR) $(LINUX_PKG) $(ROOTFS_UUID)

include ./boards/$(ARCH)/include.mk

ifneq (,$(wildcard ./boards/$(ARCH)/$(DEVICE)/include.mk))
include ./boards/$(ARCH)/$(DEVICE)/include.mk
endif

ifdef USE_EFI
EFI_MNT = /efi
EFI_IMG = $(BUILD_DIR)/efi-$(TARGET).img
EFI_UUID = $(BUILD_DIR)/efi-$(TARGET).uuid
ROOTFS_DEPS += $(EFI_UUID) $(EFI_IMG)
endif

.PHONY: default
default: $(DEV_OR_IMG)

ifneq (,$(wildcard ./boards/$(ARCH)/$(DEVICE)/recipes.mk))
include ./boards/$(ARCH)/$(DEVICE)/recipes.mk
endif

$(BASE_ROOTFS_TAR): | $(DL_DIR)
	wget -O $@ $(BASE_ROOTFS_URL)

$(BUILD_DIR) $(DL_DIR):
	mkdir -p $@

.PHONY: clean
clean: target_device_clean
	[ ! -d $(UBOOT_CLONE) ] || make -C $(UBOOT_CLONE) clean

$(LINUX_PKG): | $(DL_DIR)
	pkg_filename="$$(tar -xOf $(REPO_DB) "$$(tar -tf $(REPO_DB) | grep -E '^linux-[[:digit:]].*/desc')" | awk '/%FILENAME%/{getline; print}')" ; \
		wget -O $(LINUX_PKG) "$(ARCH_LINUX_MIRROR)$(ARCH_LINUX_MIRROR_BASE)/core/$$pkg_filename"

$(PACMAN_CACHE_DIR): | $(DL_DIR)
	mkdir $@

$(PACMAN_CACHE_SUBDIRS): | $(PACMAN_CACHE_DIR)
	mkdir $@

$(REPO_DB): | $(DL_DIR)
	wget -O $@ $(REPO_DB_URL)

$(ROOTFS_IMG): $(ROOTFS_DEPS) | $(BUILD_DIR) $(PACMAN_CACHE_SUBDIRS)
	# TODO non-static ids, maybe detect and ask for sudo
	BASE_ROOTFS_TAR=$(BASE_ROOTFS_TAR) LINUX_PKG=$(LINUX_PKG) \
		PACMAN_CACHE_DIR=$(PACMAN_CACHE_DIR) \
		ROOTFS_BUILD_DIR=$(ROOTFS_BUILD_DIR) ROOTFS_UUID=$(shell cat $(ROOTFS_UUID)) \
		ARCH=$(ARCH) \
		EFI_MNT=$(EFI_MNT) EFI_UUID=$(shell cat $(EFI_UUID)) EFI_IMG=$(EFI_IMG) \
		unshare -Umr \
			--map-users=1:$$(sed -nE "s/^$$(id -un)://p;q" /etc/subuid) \
			--map-groups=1:$$(sed -nE "s/^$$(id -gn)://p;q" /etc/subgid) \
			./setup_rootfs "$@"

$(ROOTFS_UUID): | $(BUILD_DIR)
	[ -f /proc/sys/kernel/random/uuid ] && cat /proc/sys/kernel/random/uuid > $@ || uuidgen > $@

$(EFI_UUID): | $(BUILD_DIR)
	tr -cd '0-9A-F' < /dev/urandom | head -c 8 | sed 's/./&-/4' > $@

.PHONY: uboot
uboot: | $(UBOOT_CLONE)
	make -C $(UBOOT_CLONE) $(UBOOT_DEV)

$(UBOOT_CLONE): | $(BUILD_DIR)
	git clone $(UBOOT_GIT) $(UBOOT_CLONE)

$(UBOOT_ITB): uboot
$(UBOOT_SPL): uboot
