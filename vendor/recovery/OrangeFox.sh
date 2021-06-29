#!/bin/bash
#
#	This file is part of the OrangeFox Recovery Project
# 	Copyright (C) 2018-2021 The OrangeFox Recovery Project
#
#	OrangeFox is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	any later version.
#
#	OrangeFox is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
# 	This software is released under GPL version 3 or any later version.
#	See <http://www.gnu.org/licenses/>.
#
# 	Please maintain this if you use this script or any part of it
#
# ******************************************************************************
# 05 June 2021
#
# For optional environment variables - to be declared before building,
# see "orangefox_build_vars.txt" for full details
#
# It is best to declare them in a script that you will use for building 
#
#
# whether to print extra debug messages
if [ -z "$FOX_BUILD_DEBUG_MESSAGES" ]; then
   export FOX_BUILD_DEBUG_MESSAGES="0"
elif [ "$FOX_BUILD_DEBUG_MESSAGES" = "1" ]; then
   set -o xtrace
fi

if [ "$FOX_DEBUG_BUILD_RAW_IMAGE" = "1" ]
then exit 0
fi

# some colour codes
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GREY='\033[0;37m'
LIGHTGREY='\033[0;38m'
WHITEONBLACK='\033[0;40m'
WHITEONRED='\033[0;41m'
WHITEONGREEN='\033[0;42m'
WHITEONORANGE='\033[0;43m'
WHITEONBLUE='\033[0;44m'
WHITEONPURPLE='\033[0;46m'
NC='\033[0m'
TMP_SCRATCH=/tmp/fox_build_000tmp.txt
WORKING_TMP=/tmp/Fox_000_tmp

# make sure we know exactly which "cp" command we are running
CP=/bin/cp
[ ! -x "$CP" ] && CP=cp

# exit function (cleanup first), and return status code
abort() {
  [ -d $WORKING_TMP ] && rm -rf $WORKING_TMP
  [ -f $TMP_SCRATCH ] && rm -f $TMP_SCRATCH
  exit $1
}

# extreme reduction
if [ "$FOX_EXTREME_SIZE_REDUCTION" = "1" ]; then
   export FOX_DRASTIC_SIZE_REDUCTION=1
fi

# remove all extras if FOX_DRASTIC_SIZE_REDUCTION is defined
if [ "$FOX_DRASTIC_SIZE_REDUCTION" = "1" ]; then
	export FOX_USE_BASH_SHELL=0
	export FOX_ASH_IS_BASH=0
	export FOX_USE_UNZIP_BINARY=0
	export FOX_USE_TAR_BINARY=0
	export FOX_USE_SED_BINARY=0
	export FOX_USE_GREP_BINARY=0
	export FOX_USE_NANO_EDITOR=0
	export BUILD_2GB_VERSION=0
	export FOX_REMOVE_BASH=1
	export FOX_REMOVE_AAPT=1
	export FOX_REMOVE_ZIP_BINARY=1
fi


# check out some incompatible settings
if [ "$OF_SUPPORT_ALL_BLOCK_OTA_UPDATES" = "1" ]; then
   if [ "$OF_DISABLE_MIUI_SPECIFIC_FEATURES" = "1" -o "$OF_TWRP_COMPATIBILITY_MODE" = "1" -o "$OF_VANILLA_BUILD" = "1" ]; then
      echo -e "${WHITEONRED}-- ERROR! \"OF_SUPPORT_ALL_BLOCK_OTA_UPDATES\" is incompatible with \"OF_DISABLE_MIUI_SPECIFIC_FEATURES\" or \"OF_TWRP_COMPATIBILITY_MODE\"${NC}"
      echo -e "${WHITEONRED}-- Sort out your build vars! Quitting ... ${NC}"
      abort 98
   fi
fi

if [ "$FOX_DRASTIC_SIZE_REDUCTION" = "1" -a "$BUILD_2GB_VERSION" = "1" ]; then
   echo ""
   echo -e "${WHITEONRED}-- Build OrangeFox: ERROR! ${NC}"
   echo -e "${WHITEONRED}-- Do NOT use \"FOX_DRASTIC_SIZE_REDUCTION\" and \"BUILD_2GB_VERSION\" together. Aborting! ${NC}"
   echo ""
   abort 99
fi

# export whatever has been passed on by build/core/Makefile (we expect at least 4 arguments)
if [ -n "$4" ]; then
   echo "#########################################################################"
   echo "Variables exported from build/core/Makefile:"
   echo "$@"
   export "$@"
   if [ "$FOX_VENDOR_CMD" = "Fox_Before_Recovery_Image" ]; then
      echo "# - save the vars that we might need later - " &> $TMP_SCRATCH
      echo "MKBOOTFS=\"$MKBOOTFS\"" >>  $TMP_SCRATCH
      echo "TARGET_OUT=\"$TARGET_OUT\"" >>  $TMP_SCRATCH
      echo "TARGET_RECOVERY_ROOT_OUT=\"$TARGET_RECOVERY_ROOT_OUT\"" >>  $TMP_SCRATCH
      echo "RECOVERY_RAMDISK_COMPRESSOR=\"$RECOVERY_RAMDISK_COMPRESSOR\"" >>  $TMP_SCRATCH
      echo "INTERNAL_KERNEL_CMDLINE=\"$INTERNAL_KERNEL_CMDLINE\"" >>  $TMP_SCRATCH
      echo "recovery_ramdisk=\"$recovery_ramdisk\"" >>  $TMP_SCRATCH
      echo "INTERNAL_RECOVERYIMAGE_ARGS='$INTERNAL_RECOVERYIMAGE_ARGS'" >>  $TMP_SCRATCH
      echo "INTERNAL_MKBOOTIMG_VERSION_ARGS=\"$INTERNAL_MKBOOTIMG_VERSION_ARGS\"" >>  $TMP_SCRATCH
      echo "BOARD_MKBOOTIMG_ARGS=\"$BOARD_MKBOOTIMG_ARGS\"" >>  $TMP_SCRATCH
      echo "#" >>  $TMP_SCRATCH
   fi   
   echo "#########################################################################"
else
   if [ "$FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER" = "1" ]; then
      echo -e "${WHITEONRED}-- Build OrangeFox: FATAL ERROR! ${NC}"
      echo -e "${WHITEONRED}-- You cannot use FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER without patching build/core/Makefile in the build system. Aborting! ${NC}"
      abort 100  
   fi
fi

#
RECOVERY_DIR="recovery"
FOX_VENDOR_PATH=vendor/$RECOVERY_DIR

# 
[ "$FOX_VENDOR_CMD" != "Fox_After_Recovery_Image" ] && echo -e "${RED}Building OrangeFox...${NC}"
echo -e "${BLUE}-- Setting up environment variables${NC}"

if [ "$FOX_VENDOR_CMD" = "Fox_Before_Recovery_Image" ]; then
	FOX_WORK="$TARGET_RECOVERY_ROOT_OUT"
	FOX_RAMDISK="$TARGET_RECOVERY_ROOT_OUT"
	DEFAULT_PROP_ROOT="$TARGET_RECOVERY_ROOT_OUT/../../root/default.prop"
else
	FOX_WORK=$OUT/FOX_AIK
	FOX_RAMDISK="$FOX_WORK/ramdisk"
	DEFAULT_PROP_ROOT="$FOX_WORK/../root/default.prop"
fi

# default prop
if [ -n "$TARGET_RECOVERY_ROOT_OUT" -a -e "$TARGET_RECOVERY_ROOT_OUT/default.prop" ]; then
   DEFAULT_PROP="$TARGET_RECOVERY_ROOT_OUT/default.prop"
else
   [ -e "$FOX_RAMDISK/prop.default" ] && DEFAULT_PROP="$FOX_RAMDISK/prop.default" || DEFAULT_PROP="$FOX_RAMDISK/default.prop"
fi

# device name
FOX_DEVICE=$(cut -d'_' -f2 <<<$TARGET_PRODUCT)

# build_type
if [ -z "$FOX_BUILD_TYPE" ]; then 
   export FOX_BUILD_TYPE=Unofficial
fi

# fox_version && fox_build
if [ -z "$FOX_VERSION" ]; then
   FOX_BUILD=Unofficial
else
   FOX_BUILD=$FOX_VERSION
fi

# sort out the out_name
if [ "$FOX_BUILD_TYPE" = "Unofficial" ] && [ "$FOX_BUILD" = "Unofficial" ]; then
   FOX_OUT_NAME=OrangeFox-$FOX_BUILD-$FOX_DEVICE
else
   FOX_OUT_NAME=OrangeFox-$FOX_BUILD-$FOX_BUILD_TYPE-$FOX_DEVICE
fi

RECOVERY_IMAGE="$OUT/$FOX_OUT_NAME.img"
TMP_VENDOR_PATH="$OUT/../../../../vendor/$RECOVERY_DIR"
DEFAULT_INSTALL_PARTITION="/dev/block/bootdevice/by-name/recovery" # !! DON'T change!!!

# FOX_REPLACE_BUSYBOX_PS: default to 0
if [ -z "$FOX_REPLACE_BUSYBOX_PS" ]; then
   export FOX_REPLACE_BUSYBOX_PS="0"
fi

# magiskboot
if [ "$OF_USE_MAGISKBOOT_FOR_ALL_PATCHES" = "1" ]; then
   export OF_USE_MAGISKBOOT=1
fi

# A/B devices
if [ "$OF_AB_DEVICE" = "1" ]; then
   if [ "$OF_USE_MAGISKBOOT_FOR_ALL_PATCHES" != "1" ] || [ "$OF_USE_MAGISKBOOT" != "1" ]; then
      echo -e "${RED}-- ************************************************************************************************${NC}"
      echo -e "${RED}-- OrangeFox.sh FATAL ERROR - A/B device - but other necessary vars not set. ${NC}"
      echo "-- You must do this - \"export OF_USE_MAGISKBOOT=1\" "
      echo "-- And this         - \"export OF_USE_MAGISKBOOT_FOR_ALL_PATCHES=1\" "
      echo -e "${RED}-- Quitting now ... ${NC}"
      echo -e "${RED}-- ************************************************************************************************${NC}"
      abort 200
   fi
fi

# alternative devices
[ -n "$OF_TARGET_DEVICES" -a -z "$TARGET_DEVICE_ALT" ] && export TARGET_DEVICE_ALT="$OF_TARGET_DEVICES"

# copy recovery.img
[ -f $OUT/recovery.img ] && $CP $OUT/recovery.img $RECOVERY_IMAGE

# 2GB version
RECOVERY_IMAGE_2GB=$OUT/$FOX_OUT_NAME"_lite.img"
[ -z "$BUILD_2GB_VERSION" ] && BUILD_2GB_VERSION="0" # by default, build only the full version

# exports
export FOX_DEVICE TMP_VENDOR_PATH FOX_OUT_NAME FOX_RAMDISK FOX_WORK

# create working tmp
if [ "$FOX_VENDOR_CMD" = "Fox_Before_Recovery_Image" -o -z "$FOX_VENDOR_CMD" ]; then
   rm -rf $WORKING_TMP
   mkdir -p $WORKING_TMP
fi

# ****************************************************
# --- embedded functions
# ****************************************************

# size of file
filesize() {
  [ -z "$1" -o -d "$1" ] && { echo "0"; return; }
  [ ! -e "$1" -a ! -h "$1" ] && { echo "0"; return; }
  stat -c %s "$1"
}

# file_getprop <file> <property>
file_getprop() { 
  local F=$(grep -m1 "^$2=" "$1" | cut -d= -f2)
  echo $F | sed 's/ *$//g'
}

# to save the build date, and (if desired) patch bugged alleged anti-rollback on some ROMs
Save_Build_Date() {
local DT="$1"
local F="$DEFAULT_PROP_ROOT"
   [ ! -f  "$F" ] && F="$DEFAULT_PROP"
   grep -q "ro.build.date.utc=" $F && \
   	sed -i -e "s/ro.build.date.utc=.*/ro.build.date.utc=$DT/g" $F || \
   	echo "ro.build.date.utc=$DT" >> $F

   if [ "$FOX_REPLACE_BOOTIMAGE_DATE" = "1" ]; then
      echo -e "${GREEN}-- Replacing bootimage time ${NC}"
   else
      [ -n "$2" ] && DT="$2" # don't change the true bootimage build date
   fi
   
   grep -q "ro.bootimage.build.date.utc=" $F && \
   	sed -i -e "s/ro.bootimage.build.date.utc=.*/ro.bootimage.build.date.utc=$DT/g" $F || \
   	echo "ro.bootimage.build.date.utc=$DT" >> $F
}

# if there is an ALT device, cater for it in update-binary
Add_Target_Alt() {
local D="$OF_WORKING_DIR"
local F="$D/META-INF/com/google/android/update-binary"
   if [ -n "$TARGET_DEVICE_ALT" ]; then
      sed -i -e "s/TARGET_DEVICE_ALT=.*/TARGET_DEVICE_ALT=\"$TARGET_DEVICE_ALT\"/" $F
   fi
}

# whether this is a system-as-root build
SAR_BUILD() {
  [ ! -d "$FOX_RAMDISK/system_root/" ] && { echo "0"; return; }
  local C=$(cat "$FOX_RAMDISK/etc/recovery.fstab" | grep -s ^"/system_root")
  [ -z "$C" ] && { echo "0"; return; }
  C=$(file_getprop "$DEFAULT_PROP" "ro.build.system_root_image")
  [ "$C" = "true" ] && echo "1" || echo "0"
}

# expand a directory path
fullpath() {
local T1=$PWD
  [ -z "$1" ] && return
  [ ! -d "$1" ] && {
    echo "$1"
    return
  }
  cd "$1"
  local T2=$PWD
  cd $T1
  echo "$T2"    
}

# expand
expand_vendor_path() {
  FOX_VENDOR_PATH=$(fullpath "$TMP_VENDOR_PATH")
  [ ! -d $FOX_VENDOR_PATH/installer ] && {
     local T="${BASH_SOURCE%/*}"
     T=$(fullpath $T)
     [ -x $T/OrangeFox.sh ] && FOX_VENDOR_PATH=$T
  }
}

# save build vars
save_build_vars() {
local F=$1
   export | grep "FOX_" > $F
   export | grep "OF_" >> $F
   sed -i '/FOX_BUILD_LOG_FILE/d' $F
   sed -i '/FOX_LOCAL_CALLBACK_SCRIPT/d' $F
   sed -i '/FOX_PORTS_TMP/d' $F
   sed -i '/FOX_RAMDISK/d' $F
   sed -i '/FOX_WORK/d' $F
   sed -i '/FOX_VENDOR_DIR/d' $F
   sed -i '/FOX_VENDOR_CMD/d' $F
   sed -i '/FOX_VENDOR/d' $F
   sed -i '/OF_MAINTAINER/d' $F
   sed -i '/FOX_USE_SPECIFIC_MAGISK_ZIP/d' $F
   sed -i "s/declare -x //g" $F
}

# create zip file
do_create_update_zip() {
local TDT=$(date "+%d %B %Y")
  echo -e "${BLUE}-- Creating the OrangeFox zip installer ...${NC}"
  FILES_DIR=$FOX_VENDOR_PATH/FoxFiles
  INST_DIR=$FOX_VENDOR_PATH/installer
  
  # names of output zip file(s)
  ZIP_FILE=$OUT/$FOX_OUT_NAME.zip
  ZIP_FILE_GO=$OUT/$FOX_OUT_NAME"_lite.zip"
  echo "-- Creating $ZIP_FILE for deployment ..."
  
  # clean any existing files
  rm -rf $OF_WORKING_DIR
  rm -f $ZIP_FILE_GO $ZIP_FILE

  # recreate dir
  mkdir -p $OF_WORKING_DIR
  cd $OF_WORKING_DIR

  # create some others
  mkdir -p $OF_WORKING_DIR/sdcard/Fox
  mkdir -p $OF_WORKING_DIR/META-INF/debug

  # copy documentation
  $CP -p $FOX_VENDOR_PATH/Files/INSTALL.txt .
  
  # copy recovery image
  $CP -p $RECOVERY_IMAGE ./recovery.img
   
  # copy installer bins and script 
  $CP -pr $INST_DIR/* .

  # copy FoxFiles/ to sdcard/Fox/
  $CP -a $FILES_DIR/ sdcard/Fox
  
  # any local changes to a port's installer directory?
  if [ -n "$FOX_PORTS_INSTALLER" ] && [ -d "$FOX_PORTS_INSTALLER" ]; then
     $CP -pr $FOX_PORTS_INSTALLER/* . 
  fi
  
  # patch update-binary (which is a script) to run only for the current device 
  # (mido is the default)
  local F="$OF_WORKING_DIR/META-INF/com/google/android/update-binary"
  sed -i -e "s/mido/$FOX_DEVICE/g" $F     
  sed -i -e "s/ALT_DEVICE/$FOX_DEVICE_ALT/g" $F     

  # embed the release version
  sed -i -e "s/RELEASE_VER/$FOX_BUILD/" $F

  # embed the build date
  sed -i -e "s/TODAY/$TDT/" $F

  # embed the recovery partition
  if [ -n "$FOX_RECOVERY_INSTALL_PARTITION" ]; then
     echo -e "${RED}-- Changing the recovery install partition to \"$FOX_RECOVERY_INSTALL_PARTITION\" ${NC}"
     sed -i -e "s|^RECOVERY_PARTITION=.*|RECOVERY_PARTITION=\"$FOX_RECOVERY_INSTALL_PARTITION\"|" $F
  fi

  # embed the system partition
  if [ -n "$FOX_RECOVERY_SYSTEM_PARTITION" ]; then
     echo -e "${RED}-- Changing the recovery system partition to \"$FOX_RECOVERY_SYSTEM_PARTITION\" ${NC}"
     sed -i -e "s|^SYSTEM_PARTITION=.*|SYSTEM_PARTITION=\"$FOX_RECOVERY_SYSTEM_PARTITION\"|" $F
  fi

  # embed the VENDOR partition
  if [ -n "$FOX_RECOVERY_VENDOR_PARTITION" ]; then
     echo -e "${RED}-- Changing the recovery vendor partition to \"$FOX_RECOVERY_VENDOR_PARTITION\" ${NC}"
     sed -i -e "s|^VENDOR_PARTITION=.*|VENDOR_PARTITION=\"$FOX_RECOVERY_VENDOR_PARTITION\"|" $F
  fi

  # debug mode for the installer? (just for testing purposes - don't ship the recovery with this enabled)
  if [ "$FOX_INSTALLER_DEBUG_MODE" = "1" -o "$FOX_INSTALLER_DEBUG_MODE" = "true" ]; then
     echo -e "${WHITEONRED}-- Enabling debug mode in the zip installer! You must disable \"FOX_INSTALLER_DEBUG_MODE\" before release! ${NC}"
     sed -i -e "s|^FOX_INSTALLER_DEBUG_MODE=.*|FOX_INSTALLER_DEBUG_MODE=\"1\"|" $F
  fi

  # A/B devices
  if [ "$OF_AB_DEVICE" = "1" ]; then
     echo -e "${RED}-- A/B device - copying magiskboot to zip installer ... ${NC}"
     tmp=$FOX_RAMDISK/$RAMDISK_BIN/magiskboot
     [ ! -e $tmp ] && tmp=$(find $TARGET_RECOVERY_ROOT_OUT -name magiskboot)
     [ ! -e $tmp ] && tmp=/tmp/fox_build_tmp/magiskboot
     rm -rf /tmp/fox_build_tmp/
     $CP -pf $tmp .
     sed -i -e "s/^OF_AB_DEVICE=.*/OF_AB_DEVICE=\"1\"/" $F
  fi

  # Reset Settings
  if [ "$FOX_RESET_SETTINGS" = "disabled" ]; then
     echo -e "${WHITEONRED}-- Instructing the zip installer to NOT reset OrangeFox settings (NOT recommended!) ... ${NC}"
     sed -i -e "s/^FOX_RESET_SETTINGS=.*/FOX_RESET_SETTINGS=\"disabled\"/" $F
  fi

  # skip all patches ?
  if [ "$OF_VANILLA_BUILD" = "1" ]; then
     echo -e "${RED}-- This build will skip all OrangeFox patches ... ${NC}"
     sed -i -e "s/^OF_VANILLA_BUILD=.*/OF_VANILLA_BUILD=\"1\"/" $F
  fi

  # omit AromaFM ?
  if [ "$FOX_DELETE_AROMAFM" = "1" ]; then
     echo -e "${GREEN}-- Deleting AromaFM ...${NC}"
     rm -rf $OF_WORKING_DIR/sdcard/Fox/FoxFiles/AromaFM
  fi

  # delete the magisk addon zips ?
  if [ "$FOX_DELETE_MAGISK_ADDON" = "1" ]; then
     echo -e "${GREEN}-- Deleting the magisk addon zips ...${NC}"
     rm -f $OF_WORKING_DIR/sdcard/Fox/FoxFiles/Magisk.zip
     rm -f $OF_WORKING_DIR/sdcard/Fox/FoxFiles/unrootmagisk.zip
  fi

  # are we using a specific magisk zip?
  if [ -n "$FOX_USE_SPECIFIC_MAGISK_ZIP" ]; then
     if [ -e $FOX_USE_SPECIFIC_MAGISK_ZIP ]; then
        echo -e "${WHITEONGREEN}-- Using magisk zip: \"$FOX_USE_SPECIFIC_MAGISK_ZIP\" ${NC}"
        $CP -pf $FOX_USE_SPECIFIC_MAGISK_ZIP $OF_WORKING_DIR/sdcard/Fox/FoxFiles/Magisk.zip
     else
        echo -e "${WHITEONRED}-- I cannot find \"$FOX_USE_SPECIFIC_MAGISK_ZIP\"! Using the default.${NC}"
     fi
  fi

  # initd addon
  if [ "$FOX_DELETE_INITD_ADDON" = "1" ]; then
     echo -e "${GREEN}-- Deleting the initd addon ...${NC}"
     rm -f $OF_WORKING_DIR/sdcard/Fox/FoxFiles/OF_initd*.zip
  else
     echo -e "${GREEN}-- Copying the initd addon ...${NC}"
  fi
  
  # alternative/additional device codename? (eg, "kate" (for kenzo); "willow" (for ginkgo))
  if [ -n "$TARGET_DEVICE_ALT" ]; then
     echo -e "${GREEN}-- Adding the alternative device codename: \"$TARGET_DEVICE_ALT\" ${NC}"
     Add_Target_Alt;
  fi

  # if a local callback script is declared, run it, passing to it the temporary working directory (Last call)
  # "--last-call" = just before creating the OrangeFox update zip file
  if [ -n "$FOX_LOCAL_CALLBACK_SCRIPT" ] && [ -x "$FOX_LOCAL_CALLBACK_SCRIPT" ]; then
     $FOX_LOCAL_CALLBACK_SCRIPT "$OF_WORKING_DIR" "--last-call"
  fi

  # save the build vars
  save_build_vars "$OF_WORKING_DIR/META-INF/debug/fox_build_vars.txt"
  tmp="$FOX_RAMDISK/prop.default"
  [ ! -e "$tmp" ] && tmp="$DEFAULT_PROP"
  [ ! -e "$tmp" ] && tmp="$FOX_RAMDISK/default.prop"
  [ -e "$tmp" ] && $CP "$tmp" "$OF_WORKING_DIR/META-INF/debug/default.prop"

  # create update zip
  ZIP_CMD="zip --exclude=*.git* -r9 $ZIP_FILE ."
  echo "- Running ZIP command: $ZIP_CMD"
  $ZIP_CMD -z <$FOX_VENDOR_PATH/Files/INSTALL.txt
   
  #  sign zip installer
  local JAVA8
  if [ -e "$FOX_VENDOR_PATH/signature/zipsigner-3.0.jar" ]; then
     JAVA8=$(which "java")
  else
     JAVA8="/usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java"
  fi
  [ -n "$FOX_JAVA8_PATH" ] && JAVA8="$FOX_JAVA8_PATH"
  if [ ! -x "$JAVA8" ]; then
     JAVA8="/usr/lib/jvm/java-8-openjdk/jre/bin/java"
     [ ! -x "$JAVA8" ] && JAVA8=""
  fi

  export JAVA8

  if [ -z "$JAVA8" ]; then
     echo -e "${WHITEONRED}-- java-8 cannot be found! The zip file will NOT be signed! ${NC}"
     echo -e "${WHITEONRED}-- This build CANNOT be released officially! ${NC}"
  elif [ -f $ZIP_FILE  ]; then
     ZIP_CMD="$FOX_VENDOR_PATH/signature/sign_zip.sh -z $ZIP_FILE"
     echo "- Running ZIP command: $ZIP_CMD"
     $ZIP_CMD
     # this breaks the signature
     #echo "- Adding comments (again):"
     #zip $ZIP_FILE -z <$FOX_VENDOR_PATH/Files/INSTALL.txt > /dev/null 2>&1
  fi

  # Creating ZIP md5
  echo -e "${BLUE}-- Creating md5 for $ZIP_FILE${NC}"
  cd "$OUT" && md5sum "$ZIP_FILE" > "$ZIP_FILE.md5" && cd - > /dev/null 2>&1

  # create update zip for "lite" version
  if [ "$BUILD_2GB_VERSION" = "1" ]; then
  	rm -f ./recovery.img
  	$CP -p $RECOVERY_IMAGE_2GB ./recovery.img
  	ZIP_CMD="zip --exclude=*.git* --exclude=OrangeFox*.zip* -r9 $ZIP_FILE_GO ."
  	echo "- Running ZIP command: $ZIP_CMD"
  	$ZIP_CMD -z <$FOX_VENDOR_PATH/Files/INSTALL.txt
  	
  	#  sign zip installer ("lite" version)
  	if [ -z "$JAVA8" ]; then
     	   echo -e "${WHITEONRED}-- java-8 cannot be found! The zip file will NOT be signed! ${NC}"
     	   echo -e "${WHITEONRED}-- This build CANNOT be released officially! ${NC}"
  	elif [ -f $ZIP_FILE_GO ]; then
     	   ZIP_CMD="$FOX_VENDOR_PATH/signature/sign_zip.sh -z $ZIP_FILE_GO"
     	   echo "- Running ZIP command: $ZIP_CMD"
     	   $ZIP_CMD
     	   # this breaks the signature
     	   #echo "- Adding comments (again):"
     	   #zip $ZIP_FILE_GO -z <$FOX_VENDOR_PATH/Files/INSTALL.txt > /dev/null 2>&1
     	fi
    
    # md5 lite zip
    echo -e "${BLUE}-- Creating md5 for $ZIP_FILE_GO${NC}"
    cd "$OUT" && md5sum "$ZIP_FILE_GO" > "$ZIP_FILE_GO.md5" && cd - > /dev/null 2>&1
  fi
 
  # list files
  echo "- Finished:"
  echo "---------------------------------"
  echo " $(/bin/ls -laFt $ZIP_FILE)"
  if [ "$BUILD_2GB_VERSION" = "1" ]; then
  	echo " $(/bin/ls -laFt $ZIP_FILE_GO)"
  fi
  echo "---------------------------------"
  
  # export the filenames
  echo "ZIP_FILE=$ZIP_FILE">/tmp/oFox00.tmp
  echo "RECOVERY_IMAGE=$RECOVERY_IMAGE">>/tmp/oFox00.tmp
  [ -f $RECOVERY_IMAGE".tar" ] && echo "RECOVERY_ODIN=$RECOVERY_IMAGE.tar" >>/tmp/oFox00.tmp
  if [ "$BUILD_2GB_VERSION" = "1" ]; then  
	echo "ZIP_FILE_GO=$ZIP_FILE_GO">>/tmp/oFox00.tmp
  	echo "RECOVERY_IMAGE_GO=$RECOVERY_IMAGE_2GB">>/tmp/oFox00.tmp
  fi	
  
  rm -rf $OF_WORKING_DIR # delete OF Working dir 
} # function


# create old_theme zip
do_create_old_theme_zip() {
local INST_DIR=$FOX_VENDOR_PATH/theme_installer
local F=$INST_DIR/pa.zip
local ZIP_FILE=$OUT/ClassicTheme.zip
local ZIP_CMD="zip --exclude=*.git* -r9 $ZIP_FILE ."
   cd $FOX_VENDOR_PATH/Files/classic_theme/
   rm -f $F
   zip -r0 $F * > /dev/null 2>&1
   cd $INST_DIR
   echo "- Running ZIP command: $ZIP_CMD"
   rm -f $ZIP_FILE
   $ZIP_CMD
   echo " $(/bin/ls -laFt $ZIP_FILE)"
   rm -f $F
} # function

# are we using toolbox/toybox?
uses_toolbox() {
 [ "$TW_USE_TOOLBOX" = "true" ] && { echo "1"; return; }
 local T=$(filesize $FOX_RAMDISK/sbin/toybox)
 [ "$T" = "0" ] && { echo "0"; return; }
 local B=$(filesize $FOX_RAMDISK/sbin/busybox)
 [ $T -gt $B ] && { echo "1"; return; }
 T=$(readlink "$FOX_RAMDISK/sbin/yes")
 [ "$T" = "toybox" ] && echo "1" || echo "0"
}

# Try to trim the ramdisk for really small recovery partitions
# This can reduce the recovery image size by up to 3.6 MB
reduce_ramdisk_size() {
local custom_xml=$FOX_RAMDISK/twres/pages/customization.xml
local image_xml=$FOX_RAMDISK/twres/resources/images.xml
local CURRDIR=$PWD
local TWRES_DIR=$FOX_RAMDISK/twres
local FFil="$FOX_RAMDISK/FFiles"
local C=""
local F=""

      echo -e "${GREEN}-- Pruning the ramdisk to reduce the size ... ${NC}"

      # remove some large files
      rm -rf $FFil/nano
      rm -f $FOX_RAMDISK/sbin/aapt
      rm -f $FOX_RAMDISK/sbin/zip
      rm -f $FOX_RAMDISK/sbin/nano
      rm -f $FOX_RAMDISK/sbin/gnutar
      rm -f $FOX_RAMDISK/sbin/gnused
      rm -f $FOX_RAMDISK/sbin/bash
      rm -f $FOX_RAMDISK/etc/bash.bashrc
      [ "$FOX_REPLACE_BUSYBOX_PS" != "1" ] && rm -f $FFil/ps
      rm -rf $FFil/Tools
      if [ "$OF_VANILLA_BUILD" = "1" ]; then
         rm -rf $FFil/OF_avb20
         rm -rf $FFil/OF_verity_crypt
      fi
      
      # fonts to be deleted      
      declare -a FontFiles=(
        "Amatic" 
	"Chococooky" 
	"Exo2-Medium"
	"Exo2-Regular"
	"EuclidFlex-Medium"
	"EuclidFlex-Regular"
	"GoogleSans-Medium"
	"GoogleSans-Regular"
        "FiraCode-Medium" 
	"MILanPro-Medium"
        "MILanPro-Regular")

	# first of all, substitute the fonts that will be deleted
	XML=$TWRES_DIR/themes/font.xml
	sed -i -e "s/GoogleSans/Roboto/g" $XML

	XML=$TWRES_DIR/resources/images.xml
	sed -i -e "s/EuclidFlex/Roboto/g" $XML
	sed -i -e "s/GoogleSans/Roboto/g" $XML

	XML=$TWRES_DIR/splash.xml
	sed -i -e "s/EuclidFlex/Roboto/g" $XML
	sed -i -e "s/GoogleSans/Roboto/g" $XML

	XML=$TWRES_DIR/themes/sed/splash.xml
	sed -i -e "s/EuclidFlex/Roboto/g" $XML

	XML=$TWRES_DIR/themes/sed/splash_orig.xml
	sed -i -e "s/EuclidFlex/Roboto/g" $XML

	if [ "$FOX_EXTREME_SIZE_REDUCTION" = "1" ]; then
     	   sed -i -e "s/FiraCode/Roboto/g" $TWRES_DIR/resources/images.xml
     	   sed -i -e "s/FiraCode/Roboto/g" $TWRES_DIR/splash.xml
     	fi

      	# delete the font files
      	for i in "${FontFiles[@]}"
      	do
     	   C=$i".ttf"
     	   F=$TWRES_DIR/fonts/$C
     	   rm -f $F
     	   # remove references to them in resources/images.xml 
     	   sed -i "/$C/d" $image_xml
      	done

      	# delete the matching line plus the next 2 lines
      	for i in {3..9}; do
    	   F="font"$i
     	   # remove references to them in customization.xml		   
     	   sed -i "/$F/I,+2 d" $custom_xml
      	done

	# extreme reduction: delete some pngs and one more font
	if [ "$FOX_EXTREME_SIZE_REDUCTION" = "1" ]; then
	   echo -e "${WHITEONORANGE}-- Now, we are doing some extreme pruning ... ${NC}"
	   cd $TWRES_DIR/images/Splash
	   rm -f empty.png
	   rm -f user.png
	   rm -f logo_d.png
	   rm -f logo_o.png
	   XML=$TWRES_DIR/resources/images.xml
	   sed -i -e "/Splash\//d" $XML
	   
	   # font deletion (NOTE: doing this changes the terminal font, and you may not like the result)
	   C="FiraCode-Regular.ttf"
     	   F=$TWRES_DIR/fonts/$C
     	   rm -f $F
     	   sed -i "/$C/d" $image_xml
	fi
	
	# return to where we started from
	cd $CURRDIR
}

# ****************************************************
# *** now the real work starts!
# ****************************************************

# get the full FOX_VENDOR_PATH
expand_vendor_path

# did we export tmp directory for OrangeFox ports?
[ -n "$FOX_PORTS_TMP" ] && OF_WORKING_DIR="$FOX_PORTS_TMP" || OF_WORKING_DIR="$FOX_VENDOR_PATH/tmp"

# is the working directory still there from a previous build? If so, remove it
if [ "$FOX_VENDOR_CMD" != "Fox_Before_Recovery_Image" ]; then
   if [ -d "$FOX_WORK" ]; then
      echo -e "${BLUE}-- Working folder found in OUT. Cleaning up${NC}"
      rm -rf "$FOX_WORK"
   fi

   # unpack recovery image into working directory
   echo -e "${BLUE}-- Unpacking recovery image${NC}"
   bash "$FOX_VENDOR_PATH/tools/mkboot" "$OUT/recovery.img" "$FOX_WORK" > /dev/null 2>&1

  # perhaps we don't need some "Tools" ?
  if [ "$(SAR_BUILD)" = "1" ]; then
     echo -e "${GREEN}-- This is a system-as-root build ...${NC}"
  else
     echo -e "${GREEN}-- This is NOT a system-as-root build - removing the system_sar_mount directory ...${NC}"
     rm -rf "$FOX_RAMDISK/FFiles/Tools/system_sar_mount/"
  fi
fi

###############################################################
# copy stuff to the ramdisk and do all necessary patches
if [ "$FOX_VENDOR_CMD" != "Fox_After_Recovery_Image" ]; then
   echo -e "${BLUE}-- Copying mkbootimg, unpackbootimg binaries to sbin${NC}"

   if [ -z "$TARGET_ARCH" ]; then
     echo "Arch not detected, use arm64"
     TARGET_ARCH="arm64"
   fi

  case "$TARGET_ARCH" in
  "arm")
      echo -e "${GREEN}-- ARM arch detected. Copying ARM binaries${NC}"
      $CP "$FOX_VENDOR_PATH/prebuilt/arm/mkbootimg" "$FOX_RAMDISK/sbin"
      $CP "$FOX_VENDOR_PATH/prebuilt/arm/unpackbootimg" "$FOX_RAMDISK/sbin"
      ;;
  "arm64")
      echo -e "${GREEN}-- ARM64 arch detected. Copying ARM64 binaries${NC}"
      $CP "$FOX_VENDOR_PATH/prebuilt/arm64/mkbootimg" "$FOX_RAMDISK/sbin"
      $CP "$FOX_VENDOR_PATH/prebuilt/arm64/unpackbootimg" "$FOX_RAMDISK/sbin"
      ;;
  "x86")
      echo -e "${GREEN}-- x86 arch detected. Copying x86 binaries${NC}"
      $CP "$FOX_VENDOR_PATH/prebuilt/x86/mkbootimg" "$FOX_RAMDISK/sbin"
      $CP "$FOX_VENDOR_PATH/prebuilt/x86/unpackbootimg" "$FOX_RAMDISK/sbin"
      ;;
  "x86_64")
      echo -e "${GREEN}-- x86_64 arch detected. Copying x86_64 binaries${NC}"
      $CP "$FOX_VENDOR_PATH/prebuilt/x86_64/mkbootimg" "$FOX_RAMDISK/sbin"
      $CP "$FOX_VENDOR_PATH/prebuilt/x86_64/unpackbootimg" "$FOX_RAMDISK/sbin"
      ;;
    *) echo -e "${RED}-- Couldn't detect current device architecture or it is not supported${NC}" ;;
  esac

  # build standard (3GB) version
  # copy over vendor FFiles/ and vendor sbin/ stuff before creating the boot image
  #[ "$FOX_BUILD_DEBUG_MESSAGES" = "1" ] && echo "- FOX_BUILD_DEBUG_MESSAGES: Copying: $FOX_VENDOR_PATH/FoxExtras/* to $FOX_RAMDISK/"
  $CP -pr $FOX_VENDOR_PATH/FoxExtras/* $FOX_RAMDISK/

  # copy resetprop (armeabi)
  $CP -p $FOX_VENDOR_PATH/Files/resetprop $FOX_RAMDISK/sbin/
    
  # deal with magiskboot/mkbootimg/unpackbootimg
  if [ "$OF_USE_MAGISKBOOT" != "1" ]; then
      echo -e "${GREEN}-- Not using magiskboot - deleting $FOX_RAMDISK/sbin/magiskboot ...${NC}"
      rm -f "$FOX_RAMDISK/sbin/magiskboot"
  else
     echo -e "${GREEN}-- This build will use magiskboot for patching boot images ...${NC}"
     if [ "$OF_USE_MAGISKBOOT_FOR_ALL_PATCHES" = "1" ]; then
        echo -e "${GREEN}-- Using magiskboot [$FOX_RAMDISK/sbin/magiskboot] - deleting mkbootimg/unpackbootimg ...${NC}"
        rm -f $FOX_RAMDISK/sbin/mkbootimg
        rm -f $FOX_RAMDISK/sbin/unpackbootimg
        echo -e "${GREEN}-- Backing up $FOX_RAMDISK/sbin/magiskboot to: /tmp/fox_build_tmp/ ...${NC}"
        mkdir -p /tmp/fox_build_tmp/
        $CP -pf $FOX_RAMDISK/sbin/magiskboot /tmp/fox_build_tmp/
      fi
  fi

  # try to fix toolbox egrep/fgrep symlink bug
  if [ "$(uses_toolbox)" = "1" ]; then
     rm -f $FOX_RAMDISK/sbin/egrep $FOX_RAMDISK/sbin/fgrep
     ln -sf grep $FOX_RAMDISK/sbin/egrep
     ln -sf grep $FOX_RAMDISK/sbin/fgrep
  fi
  
  # replace busybox ps with our own ?
  if [ "$FOX_REPLACE_BUSYBOX_PS" = "1" ]; then
     if [ "$(readlink $FOX_RAMDISK/sbin/ps)" = "toybox" ]; then # if using toybox, then we don't need this
     	rm -f "$FOX_RAMDISK/FFiles/ps"
     	export FOX_REPLACE_BUSYBOX_PS="0"
     	echo -e "${GREEN}-- The \"ps\" command is symlinked to \"toybox\". NOT replacing it...${NC}"
     elif [ "$(readlink $FOX_RAMDISK/sbin/ps)" = "busybox" ]; then
        if [ -f "$FOX_RAMDISK/FFiles/ps" ]; then
           echo -e "${GREEN}-- Replacing the busybox \"ps\" command with our own full version ...${NC}"
  	   rm -f $FOX_RAMDISK/sbin/ps
  	   ln -s /FFiles/ps $FOX_RAMDISK/sbin/ps
        fi
     fi
  fi

  # Replace the toolbox "getprop" with "resetprop" ?
  if [ "$FOX_REPLACE_TOOLBOX_GETPROP" = "1" -a -f $FOX_RAMDISK/sbin/resetprop ]; then
     echo -e "${GREEN}-- Replacing the toolbox \"getprop\" command with a fuller version ...${NC}"
     rm -f $FOX_RAMDISK/sbin/getprop
     ln -s resetprop $FOX_RAMDISK/sbin/getprop
  fi

  # replace busybox lzma (and "xz") with our own 
  # use the full "xz" binary for lzma, and for xz - smaller in size, and does the same job
  if [ "$OF_USE_MAGISKBOOT_FOR_ALL_PATCHES" != "1" -o "$FOX_USE_XZ_UTILS" = "1" ]; then
     echo -e "${GREEN}-- Replacing the busybox \"lzma\" command with our own full version ...${NC}"
     rm -f $FOX_RAMDISK/sbin/lzma
     rm -f $FOX_RAMDISK/sbin/xz
     $CP -p $FOX_VENDOR_PATH/Files/xz $FOX_RAMDISK/sbin/lzma
     ln -s lzma $FOX_RAMDISK/sbin/xz
  fi
  
  # system_root stuff
  if [ "$OF_SUPPORT_PRE_FLASH_SCRIPT" = "1" ]; then
     echo -e "${GREEN}-- OF_SUPPORT_PRE_FLASH_SCRIPT=1 (system_root device); copying fox_pre_flash to sbin ...${NC}"
     echo -e "${GREEN}-- Make sure that you mount both /system *and* /system_root in your fstab.${NC}"     
     $CP -p $FOX_VENDOR_PATH/Files/fox_pre_flash $FOX_RAMDISK/sbin
  fi

  # remove the green LED setting?
  if [ "$OF_USE_GREEN_LED" = "0" ]; then
     echo -e "${GREEN}-- Removing the \"green LED\" setting ...${NC}"
     Led_xml_File=$FOX_RAMDISK/twres/pages/settings.xml

     # remove the "green LED" tick box (the line where it is found + the next 2 lines)
     green_setting="fox_use_green_led"
     sed -i "/$green_setting/I,+2 d" $Led_xml_File

     # remove the text label
     green_setting="fox_led_title"
     sed -i "/$green_setting/I,+0 d" $Led_xml_File
  fi

  # remove extra "More..." link in the "About" screen?
  if [ "$OF_DISABLE_EXTRA_ABOUT_PAGE" = "1" ]; then
     echo -e "${GREEN}-- Disabling the \"More...\" link in the \"About\" page ...${NC}"
     Led_xml_File=$FOX_RAMDISK/twres/pages/settings.xml
     green_setting="btn_about_credits"
     sed -i "/$green_setting/I,+8 d" $Led_xml_File
     
     green_setting="floating_btn"
     sed -i "/$green_setting/I,+6 d" $Led_xml_File
  fi

  # remove the "splash" setting?
  if [ "$OF_NO_SPLASH_CHANGE" = "1" ]; then
     echo -e "${GREEN}-- Removing the \"splash image\" setting ...${NC}"
     Led_xml_File=$FOX_RAMDISK/twres/pages/customization.xml

     # remove the "splash" setting (the line where it is found + the next 8 lines)
     green_setting="sph_sph"
     sed -i "/$green_setting/I,+8 d" $Led_xml_File
  fi

  # disable the magisk addon ui entries?
  if [ "$FOX_DELETE_MAGISK_ADDON" = "1" ]; then
     echo -e "${GREEN}-- Disabling the magisk addon entries in advanced.xml ...${NC}"
     Led_xml_File=$FOX_RAMDISK/twres/pages/advanced.xml
     sed -i "/Magisk Manager/I,+5 d" $Led_xml_File
     #sed -i "/magisk_ver/I,+7 d" $Led_xml_File
     sed -i "/>mod_magisk</I,+0 d" $Led_xml_File
     sed -i "/>mod_unmagisk</I,+0 d" $Led_xml_File
     sed -i "s/>Magisk</>Magisk ({@disabled})</" $Led_xml_File
  fi

  # Include bash shell ?
  if [ "$FOX_REMOVE_BASH" = "1" ]; then
     export FOX_USE_BASH_SHELL="0"
     # remove bash if it is there from a previous build
     rm -f $FOX_RAMDISK/sbin/bash
     rm -f $FOX_RAMDISK/etc/bash.bashrc
  else
     echo -e "${GREEN}-- Copying bash ...${NC}"
     $CP -p $FOX_VENDOR_PATH/Files/bash $FOX_RAMDISK/sbin/bash
     $CP -p $FOX_VENDOR_PATH/Files/fox.bashrc $FOX_RAMDISK/etc/bash.bashrc
     chmod 0755 $FOX_RAMDISK/sbin/bash
     if [ "$FOX_ASH_IS_BASH" = "1" ]; then
        export FOX_USE_BASH_SHELL="1"     
     fi
  fi
  
  # replace busybox "sh" with bash ?
  if [ "$FOX_USE_BASH_SHELL" = "1" ]; then
     if [ -f "$FOX_RAMDISK/sbin/sh" ]; then 
        if [ "$FOX_DRASTIC_SIZE_REDUCTION" = "1" -o $BUILD_2GB_VERSION = "1" ]; then
           echo -e "${GREEN}-- Backing up the original \"sh\" ...${NC}"
      	   $CP -pfP $FOX_RAMDISK/sbin/sh $WORKING_TMP/
        fi

        echo -e "${GREEN}-- Replacing the busybox \"sh\" applet with bash ...${NC}"
  	rm -f $FOX_RAMDISK/sbin/sh
  	ln -s bash $FOX_RAMDISK/sbin/sh
     fi
  fi

# do the same for "ash"?
  if [ "$FOX_ASH_IS_BASH" = "1" ]; then
     if [ "$FOX_DRASTIC_SIZE_REDUCTION" = "1" -o $BUILD_2GB_VERSION = "1" ]; then
        [ -f $FOX_RAMDISK/sbin/ash -o -h $FOX_RAMDISK/sbin/ash ] && {
           echo -e "${GREEN}-- Backing up the original \"ash\" ...${NC}"
           $CP -pfP $FOX_RAMDISK/sbin/ash $WORKING_TMP/
        }
     fi
     
     [ -f $FOX_RAMDISK/sbin/ash -o -h $FOX_RAMDISK/sbin/ash ] && {
        echo -e "${GREEN}-- Replacing the \"ash\" applet with bash ...${NC}"
        rm -f $FOX_RAMDISK/sbin/ash
        ln -s bash $FOX_RAMDISK/sbin/ash
     }
  fi

  # Include nano editor ?
  if [ "$FOX_USE_NANO_EDITOR" = "1" ]; then
      echo -e "${GREEN}-- Copying nano editor ...${NC}"
      $CP -af $FOX_VENDOR_PATH/Files/nano/ $FOX_RAMDISK/FFiles/
      $CP -af $FOX_VENDOR_PATH/Files/nano/sbin/nano $FOX_RAMDISK/sbin/
  fi

  # Include standalone "tar" binary ?
  if [ "$FOX_USE_TAR_BINARY" = "1" ]; then
      echo -e "${GREEN}-- Copying the GNU \"tar\" binary (gnutar) ...${NC}"
      $CP -pf $FOX_VENDOR_PATH/Files/gnutar $FOX_RAMDISK/sbin/
      chmod 0755 $FOX_RAMDISK/sbin/gnutar
  fi

  # Include standalone "sed" binary ?
  if [ "$FOX_USE_SED_BINARY" = "1" ]; then
      echo -e "${GREEN}-- Copying the GNU \"sed\" binary (gnused) ...${NC}"
      $CP -pf $FOX_VENDOR_PATH/Files/gnused $FOX_RAMDISK/sbin/
      chmod 0755 $FOX_RAMDISK/sbin/gnused
  fi

  # Include "unzip" binary ?
  if [ "$FOX_USE_UNZIP_BINARY" = "1" -a -x $FOX_VENDOR_PATH/Files/unzip ]; then
      if [ "$FOX_DRASTIC_SIZE_REDUCTION" = "1" -o $BUILD_2GB_VERSION = "1" ]; then
         echo -e "${GREEN}-- Backing up the original unzip ...${NC}"
      	 $CP -pf $FOX_RAMDISK/sbin/unzip $WORKING_TMP/
      fi
      
      echo -e "${GREEN}-- Copying the OrangeFox InfoZip \"unzip\" binary ...${NC}"
      rm -f $FOX_RAMDISK/sbin/unzip
      $CP -pf $FOX_VENDOR_PATH/Files/unzip $FOX_RAMDISK/sbin/
      chmod 0755 $FOX_RAMDISK/sbin/unzip
  fi

  # Include "zip" binary ?
  if [ "$FOX_REMOVE_ZIP_BINARY" = "1" ]; then
      [ -e $FOX_RAMDISK/sbin/zip ] && {
         echo -e "${RED}-- Removing the OrangeFox InfoZip \"zip\" binary ...${NC}"
         rm -f $FOX_RAMDISK/sbin/zip
      }
  else
      echo -e "${GREEN}-- Copying the OrangeFox InfoZip \"zip\" binary ...${NC}"
      $CP -pf $FOX_VENDOR_PATH/Files/zip $FOX_RAMDISK/sbin/
      chmod 0755 $FOX_RAMDISK/sbin/zip
  fi

  # embed the system partition (in foxstart.sh)
  F=$FOX_RAMDISK/sbin/foxstart.sh
  if [ -n "$FOX_RECOVERY_SYSTEM_PARTITION" ]; then
     echo -e "${RED}-- Changing the recovery system partition to \"$FOX_RECOVERY_SYSTEM_PARTITION\" ${NC}"
     sed -i -e "s|^SYSTEM_PARTITION=.*|SYSTEM_PARTITION=\"$FOX_RECOVERY_SYSTEM_PARTITION\"|" $F
     # sed -i 's/^SYSTEM_PARTITION=.*/SYSTEM_PARTITION="'"$FOX_RECOVERY_SYSTEM_PARTITION"'"/' $F
  fi

  # embed the vendor partition (in foxstart.sh)
  F=$FOX_RAMDISK/sbin/foxstart.sh
  if [ -n "$FOX_RECOVERY_VENDOR_PARTITION" ]; then
     echo -e "${RED}-- Changing the recovery vendor partition to \"$FOX_RECOVERY_VENDOR_PARTITION\" ${NC}"
     sed -i -e "s|^VENDOR_PARTITION=.*|VENDOR_PARTITION=$FOX_RECOVERY_VENDOR_PARTITION|" $F
  fi

  # Include mmgui
  $CP -p $FOX_VENDOR_PATH/Files/mmgui $FOX_RAMDISK/sbin/mmgui
  chmod 0755 $FOX_RAMDISK/sbin/mmgui

  # Include aapt (1.7mb!) ?
  if [ "$FOX_REMOVE_AAPT" = "1" ]; then
     echo -e "${GREEN}-- Omitting the aapt binary ...${NC}"
     # remove aapt if it is there from a previous build
     rm -f $FOX_RAMDISK/sbin/aapt
  else
     $CP -p $FOX_VENDOR_PATH/Files/aapt $FOX_RAMDISK/sbin/aapt
     chmod 0755 $FOX_RAMDISK/sbin/aapt
  fi

  # disable the app manager?
  if [ "$FOX_DISABLE_APP_MANAGER" = "1" ]; then
     echo -e "${GREEN}-- Disabling the App Manager in advanced.xml ...${NC}"
     Led_xml_File=$FOX_RAMDISK/twres/pages/advanced.xml
     #sed -i "/appmgr_title/I,+3 d" $Led_xml_File
     sed -i '/name="{@appmgr_title}"/I,+3 d' $Led_xml_File
     # remove aapt also, as it would be redundant
     echo -e "${GREEN}-- Omitting the aapt binary ...${NC}"
     rm -f $FOX_RAMDISK/sbin/aapt
  fi

  # Include standalone "grep" binary ?
  if [ "$FOX_USE_GREP_BINARY" = "1" -a -x $FOX_VENDOR_PATH/Files/grep ]; then
      echo -e "${GREEN}-- Copying the GNU \"grep\" binary ...${NC}"
      rm -f $FOX_RAMDISK/sbin/grep $FOX_RAMDISK/sbin/egrep $FOX_RAMDISK/sbin/fgrep
      $CP -pf $FOX_VENDOR_PATH/Files/grep $FOX_RAMDISK/sbin/
      echo '#!/sbin/sh' &> "$FOX_RAMDISK/sbin/fgrep"
      echo '#!/sbin/sh' &> "$FOX_RAMDISK/sbin/egrep"
      echo 'exec grep -F "$@"' >> "$FOX_RAMDISK/sbin/fgrep"
      echo 'exec grep -E "$@"' >> "$FOX_RAMDISK/sbin/egrep"
      chmod 0755 $FOX_RAMDISK/sbin/grep $FOX_RAMDISK/sbin/fgrep $FOX_RAMDISK/sbin/egrep
  fi

  # Use a custom Maintainer Picture for about section [Yilliee]
  if [ -n "$OF_MAINTAINER_AVATAR" ]; then
      if [ -f "$OF_MAINTAINER_AVATAR" ]; then
            echo -e "${GREEN}-- Using a custom maintainer picture from $OF_MAINTAINER_AVATAR ...${NC}"
            $CP -p "$OF_MAINTAINER_AVATAR" "$FOX_RAMDISK/twres/images/Default/About/maintainer.png"
      else
            echo -e "${WHITEONRED}-- File $OF_MAINTAINER_AVATAR not found  ...${NC}"
            echo -e "${WHITEONRED}-- Using default image for maintainer's about section ...${NC}"
      fi
  fi

  # Get Magisk version
  tmp1=$FOX_VENDOR_PATH/FoxFiles/Magisk.zip
  if [ -n "$FOX_USE_SPECIFIC_MAGISK_ZIP" -a -e "$FOX_USE_SPECIFIC_MAGISK_ZIP" ]; then
     tmp1=$FOX_USE_SPECIFIC_MAGISK_ZIP
  fi
  MAGISK_VER=$(unzip -c $tmp1 common/util_functions.sh | grep MAGISK_VER= | sed -E 's+MAGISK_VER="(.*)"+\1+')
#  MAGISK_VER=$(unzip -c $FOX_VENDOR_PATH/FoxFiles/Magisk.zip common/util_functions.sh | grep MAGISK_VER= | sed -E 's+MAGISK_VER="(.*)"+\1+')
  echo -e "${GREEN}-- Detected Magisk version: ${MAGISK_VER}${NC}"
  sed -i -E "s+\"magisk_ver\" value=\"(.*)\"+\"magisk_ver\" value=\"$MAGISK_VER\"+" $FOX_RAMDISK/twres/ui.xml

  # Include text files
  $CP -p $FOX_VENDOR_PATH/Files/credits.txt $FOX_RAMDISK/twres/credits.txt
  $CP -p $FOX_VENDOR_PATH/Files/translators.txt $FOX_RAMDISK/twres/translators.txt
  $CP -p $FOX_VENDOR_PATH/Files/changelog.txt $FOX_RAMDISK/twres/changelog.txt

  # if a local callback script is declared, run it, passing to it the ramdisk directory (first call)
  if [ -n "$FOX_LOCAL_CALLBACK_SCRIPT" ] && [ -x "$FOX_LOCAL_CALLBACK_SCRIPT" ]; then
     $FOX_LOCAL_CALLBACK_SCRIPT "$FOX_RAMDISK" "--first-call"
  fi

  # reduce ramdisk size drastically?
  if [ "$FOX_DRASTIC_SIZE_REDUCTION" = "1" ]; then
     echo -e "${WHITEONRED}-- Going to do some drastic size reductions! ${NC}"
     echo -e "${WHITEONRED}-- Don't worry if you see some resource errors in the recovery's debug screen. ${NC}"
     reduce_ramdisk_size;
  fi

  # save the build date
  BUILD_DATE=$(date -u "+%c")
  BUILD_DATE_UTC=$(date "+%s")
  [ ! -e "$DEFAULT_PROP" ] && DEFAULT_PROP="$FOX_RAMDISK/default.prop"
  [ ! -e "$DEFAULT_PROP_ROOT" ] && DEFAULT_PROP_ROOT="$DEFAULT_PROP"

  # if we need to work around the bugged aosp alleged anti-rollback protection  
  if [ -n "$FOX_BUGGED_AOSP_ARB_WORKAROUND" ]; then
     echo -e "${WHITEONGREEN}-- Dealing with bugged AOSP alleged anti-ARB: setting build date to \"$FOX_BUGGED_AOSP_ARB_WORKAROUND\" (instead of the true date: \"$BUILD_DATE_UTC\") ...${NC}"
     Save_Build_Date "$FOX_BUGGED_AOSP_ARB_WORKAROUND" "$BUILD_DATE_UTC"
  else
     Save_Build_Date "$BUILD_DATE_UTC"
  fi

  # ensure that we have a proper record of the actual build date/time	
  grep -q "ro.build.date.utc_fox=" $DEFAULT_PROP_ROOT && \
  	sed -i -e "s/ro.build.date.utc_fox=.*/ro.build.date.utc_fox=$BUILD_DATE_UTC/g" $DEFAULT_PROP_ROOT || \
  	echo "ro.build.date.utc_fox=$BUILD_DATE_UTC" >> $DEFAULT_PROP_ROOT

  grep -q "ro.bootimage.build.date.utc_fox=" $DEFAULT_PROP_ROOT && \
  	sed -i -e "s/ro.bootimage.build.date.utc_fox=.*/ro.bootimage.build.date.utc_fox=$BUILD_DATE_UTC/g" $DEFAULT_PROP_ROOT || \
  	echo "ro.bootimage.build.date.utc_fox=$BUILD_DATE_UTC" >> $DEFAULT_PROP_ROOT

  #  save also to /etc/fox.cfg
  echo "FOX_BUILD_DATE=$BUILD_DATE" > $FOX_RAMDISK/etc/fox.cfg
  echo "ro.build.date.utc_fox=$BUILD_DATE_UTC" >> $FOX_RAMDISK/etc/fox.cfg
  echo "ro.bootimage.build.date.utc_fox=$BUILD_DATE_UTC" >> $FOX_RAMDISK/etc/fox.cfg
  if [ -n "$FOX_RECOVERY_SYSTEM_PARTITION" ]; then
     echo "SYSTEM_PARTITION=$FOX_RECOVERY_SYSTEM_PARTITION" >> $FOX_RAMDISK/etc/fox.cfg
  fi
  if [ -n "$FOX_RECOVERY_INSTALL_PARTITION" ]; then
     echo "RECOVERY_PARTITION=$FOX_RECOVERY_INSTALL_PARTITION" >> $FOX_RAMDISK/etc/fox.cfg
  fi
  if [ -n "$FOX_RECOVERY_VENDOR_PARTITION" ]; then
     echo "VENDOR_PARTITION=$FOX_RECOVERY_VENDOR_PARTITION" >> $FOX_RAMDISK/etc/fox.cfg
  fi

  # let's be clear where we are ...
  if [ "$FOX_VENDOR_CMD" = "Fox_Before_Recovery_Image" ]; then
     echo -e "${RED}-- Building the recovery image, using the official TWRP recovery image builder ...${NC}"
  fi
fi

# repack the recovery image
if [ -z "$FOX_VENDOR_CMD" ] || [ "$FOX_VENDOR_CMD" = "Fox_After_Recovery_Image" ]; then
     if [ "$OF_SAMSUNG_DEVICE" = "1" -o "$OF_SAMSUNG_DEVICE" = "true" ]; then
        SAMSUNG_DEVICE="samsung"
     else
        SAMSUNG_DEVICE=$(file_getprop "$DEFAULT_PROP" "ro.product.manufacturer")
     fi

     if [ -z "$SAMSUNG_DEVICE" ]; then
        SAMSUNG_DEVICE=$(grep ".manufacturer=samsung" "$DEFAULT_PROP")
        [ -n "$SAMSUNG_DEVICE" ] && SAMSUNG_DEVICE="samsung"
     fi

     if [ "$FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER" = "1" ]; then
  	echo -e "${GREEN}-- Copying recovery: \"$INSTALLED_RECOVERYIMAGE_TARGET\" --> \"$RECOVERY_IMAGE\" ${NC}"
        $CP -pf "$INSTALLED_RECOVERYIMAGE_TARGET" "$RECOVERY_IMAGE"
  	if [ "$SAMSUNG_DEVICE" = "samsung" -a "$OF_NO_SAMSUNG_SPECIAL" != "1" ]; then
     	   echo -e "${RED}-- Appending SEANDROIDENFORCE to $RECOVERY_IMAGE ${NC}"
     	   echo -n "SEANDROIDENFORCE" >> $RECOVERY_IMAGE
  	fi
  	cd "$OUT" && md5sum "$RECOVERY_IMAGE" > "$RECOVERY_IMAGE.md5" && cd - > /dev/null 2>&1
     else
  	echo -e "${BLUE}-- Repacking and copying recovery${NC}"
  	#[ "$FOX_BUILD_DEBUG_MESSAGES" = "1" ] && echo "- FOX_BUILD_DEBUG_MESSAGES: Running command: bash $FOX_VENDOR_PATH/tools/mkboot $FOX_WORK $RECOVERY_IMAGE ***"
  	if [ "$SAMSUNG_DEVICE" = "samsung" -a "$OF_NO_SAMSUNG_SPECIAL" != "1" ]; then
     	     echo -e "${RED}-- Appending SEANDROIDENFORCE to $FOX_WORK/kernel ${NC}"
     	     [ -e "$FOX_WORK/kernel" ] && echo -n "SEANDROIDENFORCE" >> "$FOX_WORK/kernel"
  	fi
  	bash "$FOX_VENDOR_PATH/tools/mkboot" "$FOX_WORK" "$RECOVERY_IMAGE" > /dev/null 2>&1
  	  if [ "$SAMSUNG_DEVICE" = "samsung" -a "$OF_NO_SAMSUNG_SPECIAL" != "1" ]; then
     	     echo -e "${RED}-- Appending SEANDROIDENFORCE to $RECOVERY_IMAGE ${NC}"
     	     echo -n "SEANDROIDENFORCE" >> $RECOVERY_IMAGE
  	fi
  	cd "$OUT" && md5sum "$RECOVERY_IMAGE" > "$RECOVERY_IMAGE.md5" && cd - > /dev/null 2>&1
     fi
     #
     if [ "$SAMSUNG_DEVICE" = "samsung" -a "$OF_NO_SAMSUNG_SPECIAL" != "1" ]; then
     	echo -e "${RED}-- Creating Odin flashable recovery tar ($RECOVERY_IMAGE.tar) ... ${NC}"
     	#tar -C $(dirname "$RECOVERY_IMAGE") -H ustar -c $(basename "$RECOVERY_IMAGE") > $RECOVERY_IMAGE".tar"
     	tar -C $(dirname "$RECOVERY_IMAGE") -H ustar -c recovery.img > $RECOVERY_IMAGE".tar"
     fi

     # end: standard version

    #: build "lite" (2GB) version (virtually obsolete now) #
    if [ "$BUILD_2GB_VERSION" = "1" ]; then
	echo -e "${RED}-- Repacking and copying the \"lite\" version of recovery${NC}"
     	echo -e "${WHITEONBLUE}-- The \"lite\" build is deprecated. Test it VERY carefully - and I sincerely hope you are making a CLEAN build!${NC}"
 	reduce_ramdisk_size "lite";
	if [ "$FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER" = "1" ]; then
	   . $TMP_SCRATCH
	   LITE_CMD=/tmp/fox_lite_build.sh

	   # create ramdisk
	   echo "#!/bin/bash" &> $LITE_CMD
	   echo "" >> $LITE_CMD
	   echo "# Pack the ramdisk" >> $LITE_CMD
	   echo "rm -f $recovery_ramdisk" >> $LITE_CMD
	   echo "$MKBOOTFS $FOX_RAMDISK | $RECOVERY_RAMDISK_COMPRESSOR >$recovery_ramdisk" >> $LITE_CMD
	   echo "" >> $LITE_CMD
	    
	   # create image
	   # remove leading and trailing quotation marks
	   LOCAL_ARGS=$(echo "$INTERNAL_RECOVERYIMAGE_ARGS" | sed -e 's/^"//' -e 's/"$//')

	   echo "# Create the recovery image" >> $LITE_CMD
	   echo "$MKBOOTIMG $INTERNAL_MKBOOTIMG_VERSION_ARGS $LOCAL_ARGS $BOARD_MKBOOTIMG_ARGS -o $RECOVERY_IMAGE_2GB" >> $LITE_CMD
	   echo "" >> $LITE_CMD
	   echo "rm -f $TMP_SCRATCH" >> $LITE_CMD
	   echo "rm -f $LITE_CMD" >> $LITE_CMD
	   echo "" >> $LITE_CMD
	   bash "$LITE_CMD"

  	   if [ "$SAMSUNG_DEVICE" = "samsung" -a "$OF_NO_SAMSUNG_SPECIAL" != "1" ]; then
     	      echo -e "${RED}-- Appending SEANDROIDENFORCE to $RECOVERY_IMAGE_2GB ${NC}"
     	      echo -n "SEANDROIDENFORCE" >> $RECOVERY_IMAGE_2GB
  	   fi

	else 
	    echo -n ""
	    #[ "$FOX_BUILD_DEBUG_MESSAGES" = "1" ] && echo "*** Running command: bash $FOX_VENDOR_PATH/tools/mkboot $FOX_WORK $RECOVERY_IMAGE_2GB ***"
	    bash "$FOX_VENDOR_PATH/tools/mkboot" "$FOX_WORK" "$RECOVERY_IMAGE_2GB" > /dev/null 2>&1
  	    if [ "$SAMSUNG_DEVICE" = "samsung" -a "$OF_NO_SAMSUNG_SPECIAL" != "1" ]; then
     	       echo -e "${RED}-- Appending SEANDROIDENFORCE to $RECOVERY_IMAGE_2GB ${NC}"
     	       echo -n "SEANDROIDENFORCE" >> $RECOVERY_IMAGE_2GB
  	    fi
	fi

	cd "$OUT" && md5sum "$RECOVERY_IMAGE_2GB" > "$RECOVERY_IMAGE_2GB.md5" && cd - > /dev/null 2>&1

        if [ "$SAMSUNG_DEVICE" = "samsung" -a "$OF_NO_SAMSUNG_SPECIAL" != "1" ]; then
     	   echo -e "${RED}-- Creating Odin flashable recovery tar ($RECOVERY_IMAGE_2GB.tar) ... ${NC}"
     	   tar -C $(dirname "$RECOVERY_IMAGE_2GB") -H ustar -c $(basename "$RECOVERY_IMAGE_2GB") > $RECOVERY_IMAGE_2GB".tar"
        fi
    fi # end: 2GB "(lite)" version

   # create update zip installer
   if [ "$OF_DISABLE_UPDATEZIP" != "1" ]; then
      	do_create_update_zip
      	
      	# create old theme zip file
      	do_create_old_theme_zip
   else
	echo -e "${RED}-- Skip creating recovery zip${NC}"
   fi

   #Info
   echo -e ""
   echo -e ""
   cat $FOX_VENDOR_PATH/Files/FoxBanner
   echo -e ""
   echo -e ""
   echo -e "===================${BLUE}Finished building OrangeFox${NC}==================="
   echo -e ""
   echo -e "${GREEN}Recovery image:${NC} $RECOVERY_IMAGE"
   echo -e "          MD5: $RECOVERY_IMAGE.md5"
   
   if [ "$OF_DISABLE_UPDATEZIP" != "1" ]; then
	echo -e ""
	echo -e "${GREEN}Recovery zip:${NC} $ZIP_FILE"
	echo -e "          MD5: $ZIP_FILE.md5"
   echo -e ""
   fi
  
   echo -e "=================================================================="

   # OrangeFox Lite
   if [ "$BUILD_2GB_VERSION" = "1" ]; then
   	echo -e ""
   	echo -e ""
   	echo -e "---------------${BLUE}Finished building OrangeFox Lite Edition${NC}---------------"
   	echo -e ""
   	echo -e "${GREEN}Recovery image:${NC} $RECOVERY_IMAGE_2GB"
   	echo -e "          MD5: $RECOVERY_IMAGE_2GB.md5"
   	if [ "$OF_DISABLE_UPDATEZIP" != "1" ]; then
   	   echo -e ""
   	   echo -e "${GREEN}Recovery zip:${NC} $ZIP_FILE_GO"
   	   echo -e "          MD5: $ZIP_FILE_GO.md5"
   	   echo -e ""
   	fi
   	echo -e "=================================================================="
   fi
   #
   if [ "$OF_DISABLE_UPDATEZIP" != "1" ]; then
   echo -e ""
   echo -e ""
   echo -e "===========================${BLUE}Classic theme${NC}=========================="
   echo -e ""
   echo -e "${GREEN}ZIP File:${NC} $OUT/ClassicTheme.zip"
   echo -e ""
   echo -e "=================================================================="
   fi
   
   # clean up, with success code
   abort 0
fi
# end!
