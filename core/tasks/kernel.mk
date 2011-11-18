#Android makefile to build kernel as a part of Android Build

ifneq ($(TARGET_PREBUILT_KERNEL),)
        $(warning **********************************************************)
        $(warning * Using prebuilt binary to replace kernel source         *)
        $(warning * Configure kernel in kernel/<vendor>/<device>           *)
        $(warning **********************************************************)
else

TARGET_AUTO_KDIR := $(shell echo $(TARGET_DEVICE_DIR) | sed -e 's/^device/kernel/g')

## Externally influenced variables
# kernel location - optional, defaults to kernel/<vendor>/<device>
TARGET_KERNEL_SOURCE ?= $(TARGET_AUTO_KDIR)
KERNEL_SRC := $(TARGET_KERNEL_SOURCE)
# kernel configuration - mandatory
KERNEL_DEFCONFIG := $(TARGET_KERNEL_CONFIG)

## Internal variables
KERNEL_OUT := $(ANDROID_BUILD_TOP)/$(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
KERNEL_CONFIG := $(KERNEL_OUT)/.config
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/arm/boot/zImage
KERNEL_HEADERS_INSTALL := $(KERNEL_OUT)/usr
KERNEL_MODULES_INSTALL := system
KERNEL_MODULES_OUT := $(TARGET_OUT)/lib/modules

ifeq "$(wildcard $(KERNEL_SRC) )" ""
        $(warning **********************************************************)
        $(warning * No kernel source found, and no prebuilt defined.       *)
        $(warning * Configure kernel in $(KERNEL_SRC))
        $(warning * Requires TARGET_KERNEL_CONFIG in AndroidBoard.mk       *)
        $(warning * Defining TARGET_PREBUILT_KERNEL can also bypass source *)
        $(warning **********************************************************)
        $(error "NO KERNEL")
else
    ifeq ($(TARGET_KERNEL_CONFIG),)
        $(warning **********************************************************)
        $(warning * Kernel source found, but no configuration was defined  *)
        $(warning * Please add the TARGET_KERNEL_CONFIG variable to your   *)
        $(warning * AndroidBoard.mk file                                   *)
        $(warning **********************************************************)
        $(error "NO KERNEL CONFIG")
    else
        #$(info Kernel source found, building it)
        ifeq ($(TARGET_USES_UNCOMPRESSED_KERNEL),true)
        $(info Using uncompressed kernel)
            KERNEL_BIN := $(KERNEL_OUT)/piggy
        else
            KERNEL_BIN := $(TARGET_PREBUILT_INT_KERNEL)
        endif
    endif
endif

define mv-modules
    mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.order`;\
    if [ "$$mdpath" != "" ];then\
        mpath=`dirname $$mdpath`;\
        ko=`find $$mpath/kernel -type f -name *.ko`;\
        for i in $$ko; do mv $$i $(KERNEL_MODULES_OUT)/; done;\
    fi
endef

define clean-module-folder
    mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.order`;\
    if [ "$$mdpath" != "" ];then\
        mpath=`dirname $$mdpath`; rm -rf $$mpath;\
    fi
endef


$(KERNEL_OUT):
	mkdir -p $(KERNEL_OUT)

$(KERNEL_CONFIG): $(KERNEL_OUT)
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- $(KERNEL_DEFCONFIG)

$(KERNEL_OUT)/piggy : $(TARGET_PREBUILT_INT_KERNEL)
	$(hide) gunzip -c $(KERNEL_OUT)/arch/arm/boot/compressed/piggy.gzip > $(KERNEL_OUT)/piggy

$(TARGET_PREBUILT_INT_KERNEL): $(KERNEL_OUT) $(KERNEL_CONFIG) $(KERNEL_HEADERS_INSTALL)
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi-
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- modules
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_OUT) INSTALL_MOD_PATH=../../$(KERNEL_MODULES_INSTALL) ARCH=arm CROSS_COMPILE=arm-eabi- modules_install
	$(mv-modules)
	$(clean-module-folder)

$(KERNEL_HEADERS_INSTALL): $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- headers_install

## Install it

file := $(INSTALLED_KERNEL_TARGET)
ALL_PREBUILT += $(file)
$(file) : $(KERNEL_BIN) | $(ACP)
	$(transform-prebuilt-to-target)

ALL_PREBUILT += $(INSTALLED_KERNEL_TARGET)

endif