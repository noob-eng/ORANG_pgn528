#
# Copyright (C) 2020 The Android Open Source Project
# Copyright (C) 2020 The TWRP Open Source Project
# Copyright (C) 2020 SebaUbuntu's TWRP device tree generator
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Inherit from those products. Most specific first.
#$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
#$(call inherit-product-if-exists, $(SRC_TARGET_DIR)/product/embedded.mk)
#$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
#$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)

# Inherit from PGN528 device
$(call inherit-product, device/condor/PGN528/device.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)

# Inherit some common Omni stuff.
#$(call inherit-product, vendor/omni/config/common.mk)
#$(call inherit-product, vendor/omni/config/gsm.mk)
PRODUCT_COPY_FILES += device/condor/PGN528/prebuilt/zImage:kernel

# Device identifier. This must come after all inclusions
PRODUCT_DEVICE := PGN528
PRODUCT_NAME := omni_PGN528
PRODUCT_BRAND := condor
PRODUCT_MODEL := PGN528
PRODUCT_MANUFACTURER := condor
PRODUCT_RELEASE_NAME := condor PGN528

# Ramdisk
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/etc/recovery.fstab:root/etc/recovery.fstab \
        $(LOCAL_PATH)/recovery/root/factory_init.project.rc:root/factory_init.project.rc \
    $(LOCAL_PATH)/recovery/root/factory_init.rc:root/factory_init.rc \
    $(LOCAL_PATH)/recovery/root/init.recovery.mt6735.rc:root/init.recovery.mt6735.rc \
    $(LOCAL_PATH)/recovery/root/meta_init.modem.rc:root/meta_init.modem.rc \
    $(LOCAL_PATH)/recovery/root/meta_init.project.rc:root/meta_init.project.rc \
    $(LOCAL_PATH)/recovery/root/meta_init.rc:root/meta_init.rc \
    $(LOCAL_PATH)/recovery/root/ueventd.mt6735.rc:root/ueventd.mt6735.rc
