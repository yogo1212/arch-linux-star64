export CROSS_COMPILE := riscv64-linux-gnu-

ARCH = riscv64

ARCH_LINUX_MIRROR = https://riscv.mirror.pkgbuild.com
ARCH_LINUX_MIRROR_BASE = /repo

BASE_ROOTFS_URL = $(ARCH_LINUX_MIRROR)/images/archriscv-latest.tar.zst

REPO_DB_URL = $(ARCH_LINUX_MIRROR)/repo/core/core.db.tar.gz

OPENSBI_CLONE = $(BUILD_DIR)/$(ARCH)/opensbi
OPENSBI_GIT = https://github.com/riscv/opensbi.git
OPENSBI_BIN = $(OPENSBI_CLONE)/build/platform/generic/firmware/fw_dynamic.bin

STAR64_EXTLINUX_PKG = $(BUILD_DIR)/uboot-extlinux-conf-hook.pkg.tar.zst
export STAR64_EXTLINUX_PKG

UBOOT_DEV = starfive_visionfive2_defconfig

TARGET_DEVICE_ROOTFS_DEPS = $(STAR64_EXTLINUX_PKG)
