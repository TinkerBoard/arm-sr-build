################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 32
override COMPILE_NS_KERNEL := 32
override COMPILE_S_USER    := 32
override COMPILE_S_KERNEL  := 32


OPTEE_OS_PLATFORM = rockchip

include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
TF_A_PATH		?= $(ROOT)/atf
BINARIES_PATH		?= $(ROOT)/out/bin
U-BOOT_PATH		?= $(ROOT)/u-boot

DEBUG = 0

################################################################################
# Targets
################################################################################
all: arm-tf u-boot
clean: arm-tf-clean u-boot-clean

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
TF_A_EXPORTS ?= CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

TF_A_DEBUG ?= $(DEBUG)
ifeq ($(TF_A_DEBUG),0)
TF_A_LOGLVL ?= 30
TF_A_OUT = $(TF_A_PATH)/build/rk3399/release
else
TF_A_LOGLVL ?= 50
TF_A_OUT = $(TF_A_PATH)/build/rk3399/debug
endif

TF_A_FLAGS ?= \
	PLAT=rk3399 \
	DEBUG=$(TF_A_DEBUG) \
	LOG_LEVEL=$(TF_A_LOGLVL)

	#BL32=$(OPTEE_OS_HEADER_V2_BIN) \
	#BL32_EXTRA1=$(OPTEE_OS_PAGER_V2_BIN) \
	#BL32_EXTRA2=$(OPTEE_OS_PAGEABLE_V2_BIN) \
	#ARM_ARCH_MAJOR=8 \
	#ARM_TSP_RAM_LOCATION=tdram \
	#BL32_RAM_LOCATION=tdram \
	#AARCH64_SP=optee \
	#BL31=${TF_A_OUT}/bl31/bl31.elf \
	#BL33=$(ROOT)/u-boot/u-boot.bin \
	#ARCH=aarch64 \

arm-tf:
	cd $(TF_A_PATH) && \
		git reset --hard refs/tags/v2.4 && \
		git clean -fdx
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) bl31



arm-tf-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) realclean

################################################################################
# U-boot
################################################################################
U-BOOT_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"\
	BL31=${TF_A_OUT}/bl31/bl31.elf \
	ARCH=arm64

U-BOOT_DEFCONFIG_FILES := \
	$(U-BOOT_PATH)/configs/tinker-board-2_defconfig \
	$(ROOT)/build/kconfig/Tinker_Board_2.config

U-BOOT_PATCHES := \
	$(ROOT)/build/0001-CapsuleCommon.patch \
	$(ROOT)/build/0002-Tinker_Board_2-DFU.patch \
	$(ROOT)/build/0003-Tinker_Board_2-dts-defconfig.patch


.PHONY: u-boot
u-boot: arm-tf
	cd $(U-BOOT_PATH) && \
		git reset --hard refs/tags/v2021.07 && \
		git clean -fdx
		
	cd $(U-BOOT_PATH) && \
		git apply $(U-BOOT_PATCHES)
	
	#rm -rf $(BINARIES_PATH)/u-boot
	mkdir -p $(BINARIES_PATH)/u-boot
	cd $(U-BOOT_PATH) && \
		scripts/kconfig/merge_config.sh -O $(BINARIES_PATH)/u-boot $(U-BOOT_DEFCONFIG_FILES)
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) O=$(BINARIES_PATH)/u-boot all

.PHONY: capsule
capsule: arm-tf
	cd $(U-BOOT_PATH) && \
		git reset --hard refs/tags/v2021.07 && \
		git clean -fdx
	cd $(U-BOOT_PATH) && \
		git apply $(U-BOOT_PATCHES)
	
	#rm -rf $(BINARIES_PATH)/capsule
	mkdir -p $(BINARIES_PATH)/capsule
	cd $(U-BOOT_PATH) && \
		scripts/kconfig/merge_config.sh -O $(BINARIES_PATH)/capsule $(U-BOOT_DEFCONFIG_FILES) $(ROOT)/build/kconfig/Capsule.config
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) O=$(BINARIES_PATH)/capsule all
	cp $(ROOT)/build/acapsule.its $(BINARIES_PATH)/capsule/acapsule.its
	cd $(BINARIES_PATH)/capsule && \
		tools/mkimage -f $(BINARIES_PATH)/capsule/acapsule.its capsule.itb
	cd $(BINARIES_PATH)/capsule && \
		tools/mkeficapsule --fit $(BINARIES_PATH)/capsule/capsule.itb --index 1 capsule.bin


.PHONY: u-boot-clean
u-boot-clean:
	rm -rf $(BINARIES_PATH)/u-boot
	rm -rf $(BINARIES_PATH)/capsule
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) distclean


