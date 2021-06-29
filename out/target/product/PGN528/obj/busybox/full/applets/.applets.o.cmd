cmd_applets/applets.o := /root/oran/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-gcc -Wp,-MD,applets/.applets.o.d  -std=gnu99 -Iinclude -Ilibbb -Iinclude2 -I/root/oran/external/busybox/include -I/root/oran/external/busybox/libbb -include include/autoconf.h -D_GNU_SOURCE -DNDEBUG  -D"BB_VER=KBUILD_STR(1.22.1)" -DBB_BT=AUTOCONF_TIMESTAMP -I/root/oran/external/busybox/applets -Iapplets -Wall -Wshadow -Wwrite-strings -Wundef -Wstrict-prototypes -Wunused -Wunused-parameter -Wunused-function -Wunused-value -Wmissing-prototypes -Wmissing-declarations -Wno-format-security -Wdeclaration-after-statement -Wold-style-definition -fno-builtin-strlen -finline-limit=0 -fomit-frame-pointer -ffunction-sections -fdata-sections -fno-guess-branch-probability -funsigned-char -static-libgcc -falign-functions=1 -falign-jumps=1 -falign-labels=1 -falign-loops=1 -fno-unwind-tables -fno-asynchronous-unwind-tables -Os -Os -fno-short-enums -fgcse-after-reload -frerun-cse-after-loop -frename-registers  -D"KBUILD_STR(s)=#s" -D"KBUILD_BASENAME=KBUILD_STR(applets)"  -D"KBUILD_MODNAME=KBUILD_STR(applets)" -c -o applets/applets.o /root/oran/external/busybox/applets/applets.c

deps_applets/applets.o := \
  /root/oran/external/busybox/applets/applets.c \
    $(wildcard include/config/build/libbusybox.h) \

applets/applets.o: $(deps_applets/applets.o)

$(deps_applets/applets.o):
