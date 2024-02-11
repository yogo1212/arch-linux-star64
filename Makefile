BUILD_DIR = build
DL_DIR = dl

export CROSS_COMPILE := riscv64-linux-gnu-

ARCH_LINUX_MIRROR = https://riscv.mirror.pkgbuild.com

BASE_ROOTFS_TAR = $(DL_DIR)/base_rootfs.tar.zst
BASE_ROOTFS_URL = $(ARCH_LINUX_MIRROR)/images/archriscv-latest.tar.zst

DTB_REL_PATH = boot/star64.dtb

LINUX_PKG = $(DL_DIR)/linux.pkg.tar.zst

OPENSBI_CLONE = $(BUILD_DIR)/opensbi
OPENSBI_GIT = https://github.com/riscv/opensbi.git
OPENSBI_BIN = $(OPENSBI_CLONE)/build/platform/generic/firmware/fw_dynamic.bin

PACMAN_CACHE_DIR = $(DL_DIR)/pacman_cache/

REPO_DB = $(DL_DIR)/core.db.tar.gz
REPO_DB_URL = $(ARCH_LINUX_MIRROR)/repo/core/core.db.tar.gz

ROOTFS_IMG = $(BUILD_DIR)/rootfs.img
ROOTFS_BUILD_DIR = $(BUILD_DIR)/rootfs
ROOTFS_UUID = $(BUILD_DIR)/rootfs.uuid
ROOTFS_WIGGLEROOM_MB ?= 256

export ROOTFS_WIGGLEROOM_MB

SF2_DTB_URL = https://github.com/starfive-tech/VisionFive2/releases/download/JH7110_VF2_515_v5.10.3/jh7110-visionfive-v2.dtb
STAR64_EXTLINUX_PKG = $(BUILD_DIR)/star64-extlinux.pkg.tar.zst

UBOOT_CLONE = $(BUILD_DIR)/u-boot
UBOOT_GIT = https://github.com/u-boot/u-boot.git
UBOOT_SPL = $(UBOOT_CLONE)/spl/u-boot-spl.bin.normal.out
UBOOT_ITB = $(UBOOT_CLONE)/u-boot.itb

UBOOT_ENV_NAME = star64
UBOOT_DEFAULT_ENV = $(UBOOT_CLONE)/board/starfive/visionfive2/$(UBOOT_ENV_NAME).env

IMG_NAME ?= $(BUILD_DIR)/star64.img

.PHONY: .default
default: $(IMG_NAME)

$(BASE_ROOTFS_TAR): | $(DL_DIR)
	wget -O $@ $(BASE_ROOTFS_URL)

$(BUILD_DIR) $(DL_DIR):
	mkdir -p $@

.PHONY: clean
clean:
	[ ! -d $(UBOOT_CLONE) ] || make -C $(UBOOT_CLONE) clean
	[ ! -d $(OPENSBI_CLONE) ] || make -C $(OPENSBI_CLONE) clean

.PHONY: fit
fit: $(IMG_NAME)
	./fit_image $(IMG_NAME)

$(IMG_NAME): $(ROOTFS_IMG) $(UBOOT_ITB) $(UBOOT_SPL)
	ROOTFS_IMG=$(ROOTFS_IMG) UBOOT_ITB=$(UBOOT_ITB) UBOOT_SPL=$(UBOOT_SPL) ./compile_image $@

$(LINUX_PKG): | $(DL_DIR)
	pkg_filename="$$(tar -xOf $(REPO_DB) "$$(tar -tf $(REPO_DB) | grep -E '^linux-[[:digit:]].*/desc')" | awk '/%FILENAME%/{getline; print}')" ; \
		wget -O $(LINUX_PKG) "$(ARCH_LINUX_MIRROR)/repo/core/$$pkg_filename"

.PHONY: opensbi
opensbi: $(OPENSBI_BIN)

$(OPENSBI_BIN): | $(OPENSBI_CLONE)
	# TODO update?
	#git -C $(OPENSBI_CLONE) ls-remote --refs --sort="version:refname" --tags $(OPENSBI_GIT) | cut -d/ -f3-|tail -n1
	make -C $(OPENSBI_CLONE) PLATFORM=generic FW_TEXT_START=0x40000000 FW_OPTIONS=0 FW_DYNAMIC=y

$(OPENSBI_CLONE): | $(BUILD_DIR)
	git clone $(OPENSBI_GIT) $(OPENSBI_CLONE)

$(PACMAN_CACHE_DIR): | $(DL_DIR)
	mkdir $@

$(REPO_DB): | $(DL_DIR)
	wget -O $@ $(REPO_DB_URL)

$(ROOTFS_IMG): $(BASE_ROOTFS_TAR) $(LINUX_PKG) $(ROOTFS_UUID) $(STAR64_EXTLINUX_PKG) | $(BUILD_DIR) $(PACMAN_CACHE_DIR)
	# TODO non-static ids, maybe detect and ask for sudo
	BASE_ROOTFS_TAR=$(BASE_ROOTFS_TAR) LINUX_PKG=$(LINUX_PKG) \
		PACMAN_CACHE_DIR=$(PACMAN_CACHE_DIR) \
		ROOTFS_BUILD_DIR=$(ROOTFS_BUILD_DIR) ROOTFS_UUID=$(shell cat $(ROOTFS_UUID)) \
		STAR64_EXTLINUX_PKG=$(STAR64_EXTLINUX_PKG) \
		unshare -Umr \
			--map-users=1:$$(sed -nE "s/^$$(id -un)://p;q" /etc/subuid) \
			--map-groups=1:$$(sed -nE "s/^$$(id -gn)://p;q" /etc/subgid) \
			./setup_rootfs "$@"

$(ROOTFS_UUID):
	uuidgen > $@

$(STAR64_EXTLINUX_PKG): $(ROOTFS_UUID)
	cd star64-extlinux ;\
		CARCH=riscv64 makepkg -f ROOTFS_UUID=$(shell cat $(ROOTFS_UUID)) SF2_DTB_URL=$(SF2_DTB_URL)
	# TODO pass in version from make as well? could then be used to construct filename
	cp star64-extlinux/star64-extlinux-0.1-1-riscv64.pkg.tar.zst $@

.PHONY: uboot
uboot: $(OPENSBI_BIN) $(UBOOT_DEFAULT_ENV) | $(UBOOT_CLONE)
	make -C $(UBOOT_CLONE) starfive_visionfive2_defconfig
	cd $(UBOOT_CLONE) ; \
		scripts/config \
			--set-str CONFIG_ENV_SOURCE_FILE star64
	make -C $(UBOOT_CLONE) \
		OPENSBI=$(abspath $(OPENSBI_BIN))

.PHONY: $(UBOOT_DEFAULT_ENV)
$(UBOOT_DEFAULT_ENV): | $(UBOOT_CLONE)
	./create_default_uboot_env > $@

$(UBOOT_CLONE): | $(BUILD_DIR)
	git clone $(UBOOT_GIT) $(UBOOT_CLONE)

$(UBOOT_ITB): uboot
$(UBOOT_SPL): uboot

