FUSE_ROOT := $(call my-dir)

LINKS := fsck.exfat mkfs.exfat

LOCAL_PATH := $(call my-dir)

# multi-call binary
include $(CLEAR_VARS)
LOCAL_MODULE := mount.exfat
LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES := main.c
LOCAL_SHARED_LIBRARIES += libz libc
LOCAL_STATIC_LIBRARIES += libexfat_mount libexfat_fsck libexfat_mkfs
LOCAL_STATIC_LIBRARIES += libexfat libfuse_static
include $(BUILD_EXECUTABLE)

SYMLINKS := $(addprefix $(TARGET_OUT)/bin/,$(LINKS))
$(SYMLINKS): EXFAT_BINARY := $(LOCAL_MODULE)
$(SYMLINKS): $(LOCAL_INSTALLED_MODULE) $(LOCAL_PATH)/Android.mk
	@echo "Symlink: $@ -> $(EXFAT_BINARY)"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) ln -sf $(EXFAT_BINARY) $@

ALL_DEFAULT_INSTALLED_MODULES += $(SYMLINKS)

include $(FUSE_ROOT)/libexfat/Android.mk
include $(FUSE_ROOT)/fuse/Android.mk
include $(FUSE_ROOT)/mkfs/Android.mk
include $(FUSE_ROOT)/fsck/Android.mk
