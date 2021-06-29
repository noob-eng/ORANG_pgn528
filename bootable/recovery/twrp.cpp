/*
	This file is part of TWRP/TeamWin Recovery Project.

	Copyright (C) 2018-2020 OrangeFox Recovery Project
	This file is part of the OrangeFox Recovery Project.

	TWRP is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	TWRP is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with TWRP.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>
#include "gui/twmsg.h"

#include "cutils/properties.h"
#include "bootloader_message_twrp/include/bootloader_message_twrp/bootloader_message.h"

#ifdef ANDROID_RB_RESTART
#include "cutils/android_reboot.h"
#else
#include <sys/reboot.h>
#endif

extern "C" {
#include "gui/gui.h"
}
#include "set_metadata.h"
#include "gui/gui.hpp"
#include "gui/pages.hpp"
#include "gui/objects.hpp"
#include "twcommon.h"
#include "twrp-functions.hpp"
#include "data.hpp"
#include "partitions.hpp"

#if SDK_VERSION >= 24
#include <android-base/strings.h>
#elif SDK_VERSION == 23
#include <base/strings.h>
#else
#include <strings.h>
#endif
#include "openrecoveryscript.hpp"
#include "variables.h"
#include "twrpAdbBuFifo.hpp"
#ifdef TW_USE_NEW_MINADBD
#include "minadbd/minadbd.h"
#else
extern "C" {
#include "minadbd21/adb.h"
}
#endif

//extern int adb_server_main(int is_daemon, int server_port, int /* reply_fd */);

TWPartitionManager PartitionManager;
int Log_Offset;
bool datamedia;

static void Print_Prop(const char *key, const char *name, void *cookie)
{
  printf("%s=%s\n", key, name);
}

int main(int argc, char **argv)
{
  //[f/d] Disable LED as early as possible
  DataManager::Leds(false);

	//Also disable adbd
	#ifdef FOX_ADVANCED_SECURITY
  property_set("ctl.stop", "adbd");
  property_set("orangefox.adb.status", "0");
	#endif

  // Recovery needs to install world-readable files, so clear umask
  // set by init
  umask(0);

  Log_Offset = 0;

  // Set up temporary log file (/tmp/recovery.log)
  freopen(TMP_LOG_FILE, "a", stdout);
  setbuf(stdout, NULL);
  freopen(TMP_LOG_FILE, "a", stderr);
  setbuf(stderr, NULL);

  signal(SIGPIPE, SIG_IGN);

  // Handle ADB sideload
  if (argc == 3 && strcmp(argv[1], "--adbd") == 0)
    {
      property_set("ctl.stop", "adbd");
#ifdef TW_USE_NEW_MINADBD
      minadbd_main();
#else
      adb_main(argv[2]);
#endif
      return 0;
    }

#ifdef RECOVERY_SDCARD_ON_DATA
  datamedia = true;
#endif

  char crash_prop_val[PROPERTY_VALUE_MAX];
  int crash_counter;
  property_get("orangefox.crash_counter", crash_prop_val, "-1");
  crash_counter = atoi(crash_prop_val) + 1;
  snprintf(crash_prop_val, sizeof(crash_prop_val), "%d", crash_counter);
  property_set("orangefox.crash_counter", crash_prop_val);
  property_set("ro.orangefox.boot", "1");
  property_set("ro.orangefox.build", "orangefox");
  property_set("ro.orangefox.version", FOX_VERSION);
  
  string fox_build_date = TWFunc::File_Property_Get ("/etc/fox.cfg", "FOX_BUILD_DATE");
  if (fox_build_date == "")
     {
        fox_build_date = TWFunc::File_Property_Get ("/default.prop", "ro.bootimage.build.date");
        if (fox_build_date == "")
          {
              fox_build_date = TWFunc::File_Property_Get ("/default.prop", "ro.build.date");
              if (fox_build_date == "")
                 fox_build_date = "[no date!]";
         }
     }
  DataManager::SetValue("FOX_BUILD_DATE_REAL", fox_build_date);

  // set the start date to the recovery's build date
  TWFunc::Reset_Clock();

  DataManager::GetValue(FOX_COMPATIBILITY_DEVICE, Fox_Current_Device);
  printf("Starting OrangeFox Recovery %s [core: %s] (built on %s for %s [dev_ver: %s]; pid %d)\n",
  	FOX_BUILD, FOX_MAIN_VERSION_STR, fox_build_date.c_str(), Fox_Current_Device.c_str(), FOX_CURRENT_DEV_STR, getpid());

  // Load default values to set DataManager constants and handle ifdefs
	DataManager::SetDefaultValues();
	printf("Starting the UI...\n");
	gui_init();
	printf("=> Linking mtab\n");
	symlink("/proc/mounts", "/etc/mtab");
	std::string fstab_filename = "/etc/twrp.fstab";
	if (!TWFunc::Path_Exists(fstab_filename)) {
		fstab_filename = "/etc/recovery.fstab";
	}

	// Begin SAR detection
	{
		TWPartitionManager SarPartitionManager;
		printf("=> Processing %s for SAR-detection\n", fstab_filename.c_str());
		if (!SarPartitionManager.Process_Fstab(fstab_filename, 1, 1)) {
			LOGERR("Failing out of recovery due to problem with fstab.\n");
			return -1;
		}

		mkdir("/s", 0755);

#if defined(AB_OTA_UPDATER) || defined(__ANDROID_API_Q__)
		bool fallback_sar = true;
#else
		bool fallback_sar = property_get_bool("ro.build.system_root_image", false);
#endif

#ifdef OF_USE_TWRP_SAR_DETECT
		if(SarPartitionManager.Mount_By_Path("/s", false)) {
			if (TWFunc::Path_Exists("/s/build.prop")) {
				LOGINFO("SAR-DETECT: Non-SAR System detected\n");
				property_set("ro.twrp.sar", "false");
				rmdir("/system_root");
			} else if (TWFunc::Path_Exists("/s/system/build.prop")) {
				LOGINFO("SAR-DETECT: SAR System detected\n");
				property_set("ro.twrp.sar", "true");
			} else {
				LOGINFO("SAR-DETECT: No build.prop found, falling back to %s\n", fallback_sar ? "SAR" : "Non-SAR");
				property_set("ro.twrp.sar", fallback_sar ? "true" : "false");
			}

// We are doing this here during SAR-detection, since we are mounting the system-partition anyway
// This way we don't need to remount it later, just for overriding properties
#if defined(TW_INCLUDE_LIBRESETPROP) && defined(TW_OVERRIDE_SYSTEM_PROPS)
			stringstream override_props(EXPAND(TW_OVERRIDE_SYSTEM_PROPS));
			string current_prop;
			while (getline(override_props, current_prop, ';')) {
				string other_prop;
				if (current_prop.find("=") != string::npos) {
					other_prop = current_prop.substr(current_prop.find("=") + 1);
					current_prop = current_prop.substr(0, current_prop.find("="));
				} else {
					other_prop = current_prop;
				}
				other_prop = android::base::Trim(other_prop);
				current_prop = android::base::Trim(current_prop);
				string sys_val = TWFunc::System_Property_Get(other_prop, SarPartitionManager, "/s");
				if (!sys_val.empty()) {
					LOGINFO("Overriding %s with value: \"%s\" from system property %s\n", current_prop.c_str(), sys_val.c_str(), other_prop.c_str());
					int error = TWFunc::Property_Override(current_prop, sys_val);
					if (error) {
						LOGERR("Failed overriding property %s, error_code: %d\n", current_prop.c_str(), error);
					}
				} else {
					LOGINFO("Not overriding %s with empty value from system property %s\n", current_prop.c_str(), other_prop.c_str());
				}
			}
#endif
			SarPartitionManager.UnMount_By_Path("/s", false);
		} else {
			LOGINFO("SAR-DETECT: Could not mount system partition, falling back to %s\n", fallback_sar ? "SAR":"Non-SAR");
			property_set("ro.twrp.sar", fallback_sar ? "true" : "false");
		}

		rmdir("/s");

		TWFunc::check_and_run_script("/sbin/sarsetup.sh", "boot");

#else // OF_USE_TWRP_SAR_DETECT
    if (fallback_sar)
       {
	  LOGINFO("FOX-SAR-DETECT: SAR System detected\n");
	  property_set("ro.twrp.sar", "true");
       }
    else
       {
	  LOGINFO("FOX-SAR-DETECT: Non-SAR System detected\n");
	  property_set("ro.twrp.sar", "false");
	  rmdir("/system_root");
       }
    rmdir ("/s");
    TWFunc::check_and_run_script("/sbin/sarsetup.sh", "boot");
#endif // OF_USE_TWRP_SAR_DETECT

	}
	// End SAR detection

	printf("=> Processing %s\n", fstab_filename.c_str());
	if (!PartitionManager.Process_Fstab(fstab_filename, 1, 0)) {
		LOGERR("Failing out of recovery due to problem with fstab.\n");
		return -1;
	}
	PartitionManager.Output_Partition_Logging();

        // run the startup script early
        TWFunc::RunStartupScript();

        // use the ROM's fingerprint?
	#ifdef OF_USE_SYSTEM_FINGERPRINT
        TWFunc::UseSystemFingerprint();
	#endif

	// Check for and run startup script if script exists
	TWFunc::RunFoxScript("/sbin/runatboot.sh");

	// Load up all the resources
	gui_loadResources();

	bool Shutdown = false;

	string Send_Intent = "";
	{
		TWPartition* misc = PartitionManager.Find_Partition_By_Path("/misc");
		if (misc != NULL) {
			if (misc->Current_File_System == "emmc") {
				set_misc_device(misc->Actual_Block_Device.c_str());
			} else {
				LOGERR("Only emmc /misc is supported\n");
			}
		}
		get_args(&argc, &argv);

		int index, index2, len;
		char* argptr;
		char* ptr;
		printf("Startup Commands: ");
		for (index = 1; index < argc; index++) {
			if (strcmp(argv[index], "--prompt_and_wipe_data") == 0) // Rescue Party ?
			   {
			      gui_print_color("error",
			      "\nOrangeFox: Android Rescue Party trigger! Possible solutions? Either: \n  1. Wipe data and caches, or\n  2. Format data, and/or\n  3. Clean-flash your ROM.\n\n");
			   }

			argptr = argv[index];
			printf(" '%s'", argv[index]);
			len = strlen(argv[index]);
			if (*argptr == '-') {argptr++; len--;}
			if (*argptr == '-') {argptr++; len--;}
			if (*argptr == 'u') {
				ptr = argptr;
				index2 = 0;
				while (*ptr != '=' && *ptr != '\n')
					ptr++;
				// skip the = before grabbing Zip_File
				while (*ptr == '=')
					ptr++;
				if (*ptr) {
					string ORSCommand = "install ";
					ORSCommand.append(ptr);

					if (!OpenRecoveryScript::Insert_ORS_Command(ORSCommand))
						break;
				} else
					LOGERR("argument error specifying zip file\n");
			} else if (*argptr == 'w') {
				if (len == 9) {
					if (!OpenRecoveryScript::Insert_ORS_Command("wipe data\n"))
						break;
				} else if (len == 10) {
					if (!OpenRecoveryScript::Insert_ORS_Command("wipe cache\n"))
						break;
				}
				// Other 'w' items are wipe_ab and wipe_package_size which are related to bricking the device remotely. 
				// We will not bother to support these as having TWRP probably makes "bricking" the device in this manner useless
			} else if (*argptr == 'n') {
				DataManager::SetValue(TW_BACKUP_NAME, gui_parse_text("{@auto_generate}"));
				if (!OpenRecoveryScript::Insert_ORS_Command("backup BSDCAE\n"))
					break;
			} else if (*argptr == 'p') {
				Shutdown = true;
			} else if (*argptr == 's') {
				if (strncmp(argptr, "send_intent", strlen("send_intent")) == 0) {
					ptr = argptr + strlen("send_intent") + 1;
					Send_Intent = *ptr;
				} else if (strncmp(argptr, "security", strlen("security")) == 0) {
					LOGINFO("Security update\n");
				} else if (strncmp(argptr, "sideload", strlen("sideload")) == 0) {
					if (!OpenRecoveryScript::Insert_ORS_Command("sideload\n"))
						break;
				} else if (strncmp(argptr, "stages", strlen("stages")) == 0) {
					LOGINFO("ignoring stages command\n");
				}
			} else if (*argptr == 'r') {
				if (strncmp(argptr, "reason", strlen("reason")) == 0) {
					ptr = argptr + strlen("reason") + 1;
					gui_print("%s\n", ptr);
				}
			}
		}
		printf("\n");
	}

	if (crash_counter == 0) {
		property_list(Print_Prop, NULL);
		printf("\n");
	} else {
		printf("orangefox.crash_counter=%d\n", crash_counter);
	}

#ifdef TW_INCLUDE_INJECTTWRP
	// Back up OrangeFox Ramdisk if needed:
	TWPartition* Boot = PartitionManager.Find_Partition_By_Path("/boot");
	LOGINFO("Backing up OrangeFox ramdisk...\n");
	if (Boot == NULL || Boot->Current_File_System != "emmc")
		TWFunc::Exec_Cmd("injecttwrp --backup /tmp/backup_recovery_ramdisk.img");
	else {
		string injectcmd = "injecttwrp --backup /tmp/backup_recovery_ramdisk.img bd=" + Boot->Actual_Block_Device;
		TWFunc::Exec_Cmd(injectcmd);
	}
	LOGINFO("Backup of OrangeFox ramdisk done.\n");
#endif

#ifdef FOX_ADVANCED_SECURITY
  property_set("ctl.stop", "adbd");
  property_set("orangefox.adb.status", "0");
#endif

	// Offer to decrypt if the device is encrypted
	if (DataManager::GetIntValue(TW_IS_ENCRYPTED) != 0) {
		LOGINFO("Is encrypted, do decrypt page first\n");
		if (gui_startPage("decrypt", 1, 1) != 0) {
			LOGERR("Failed to start decrypt GUI page.\n");
		} else {
			// Check for and load custom theme if present
			TWFunc::check_selinux_support();
			gui_loadCustomResources();
			// OrangeFox - make note of this decryption
			DataManager::SetValue("OTA_decrypted", "1");
			#ifdef FOX_OLD_DECRYPT_RELOAD
				DataManager::SetValue("used_custom_encryption", "1");
			#endif
			usleep(16);
		}
	} else if (datamedia) {
		TWFunc::check_selinux_support();
		if (tw_get_default_metadata(DataManager::GetSettingsStoragePath().c_str()) != 0) {
			LOGINFO("Failed to get default contexts and file mode for storage files.\n");
		} else {
			LOGINFO("Got default contexts and file mode for storage files.\n");
		}
	}

	// Fixup the RTC clock on devices which require it
	if (crash_counter == 0)
		TWFunc::Fixup_Time_On_Boot();

	// Read the settings file
	TWFunc::Update_Log_File();
	DataManager::ReadSettingsFile();
	PageManager::LoadLanguage(DataManager::GetStrValue("tw_language"));
	GUIConsole::Translate_Now();

  	// implement any relevant dm-verity/forced-encryption build vars
  	TWFunc::Setup_Verity_Forced_Encryption();

	// Run any outstanding OpenRecoveryScript
	std::string cacheDir = TWFunc::get_log_dir();
	if (cacheDir == DATA_LOGS_DIR)
		cacheDir = "/data/cache";
	std::string orsFile = cacheDir + "/recovery/openrecoveryscript";
	
	if (TWFunc::Path_Exists(SCRIPT_FILE_TMP) || (DataManager::GetIntValue(TW_IS_ENCRYPTED) == 0 && TWFunc::Path_Exists(orsFile))) {
		OpenRecoveryScript::Run_OpenRecoveryScript();
	}

  	// call OrangeFox startup code
  	TWFunc::OrangeFox_Startup();

#ifdef FOX_ADVANCED_SECURITY
	LOGINFO("ADB & MTP disabled by maintainer\n");
	DataManager::SetValue("fox_advanced_security", "1");
  DataManager::SetValue("tw_mtp_enabled", 0);
#else
#ifdef TW_HAS_MTP
	char mtp_crash_check[PROPERTY_VALUE_MAX];
	property_get("mtp.crash_check", mtp_crash_check, "0");
	if (DataManager::GetIntValue("tw_mtp_enabled")
			&& !strcmp(mtp_crash_check, "0") && !crash_counter
			&& (!DataManager::GetIntValue(TW_IS_ENCRYPTED) || DataManager::GetIntValue(TW_IS_DECRYPTED))) {
		property_set("mtp.crash_check", "1");
		LOGINFO("Starting MTP\n");
		if (!PartitionManager.Enable_MTP())
			PartitionManager.Disable_MTP();
		else
			gui_msg("mtp_enabled=MTP Enabled");
		property_set("mtp.crash_check", "0");
	} else if (strcmp(mtp_crash_check, "0")) {
		gui_warn("mtp_crash=MTP Crashed, not starting MTP on boot.");
		DataManager::SetValue("tw_mtp_enabled", 0);
		PartitionManager.Disable_MTP();
	} else if (crash_counter == 1) {
		LOGINFO("OrangeFox crashed; disabling MTP as a precaution.\n");
		PartitionManager.Disable_MTP();
	}
#endif
#endif

#ifndef TW_OEM_BUILD
	// Check if system has never been changed
	TWPartition* sys = PartitionManager.Find_Partition_By_Path(PartitionManager.Get_Android_Root_Path());
	TWPartition* ven = PartitionManager.Find_Partition_By_Path("/vendor");

  if (sys)
    {
      if ((DataManager::GetIntValue("tw_mount_system_ro") == 0
	   && sys->Check_Lifetime_Writes() == 0)
	  || DataManager::GetIntValue("tw_mount_system_ro") == 2)
	{
	  if (DataManager::GetIntValue("tw_never_show_system_ro_page") == 0)
	    {
	      DataManager::SetValue("tw_back", "main");
	      if (gui_startPage("system_readonly", 1, 1) != 0)
		{
		  LOGERR("Failed to start system_readonly GUI page.\n");
		}
	    }
	  else if (DataManager::GetIntValue("tw_mount_system_ro") == 0)
	    {
	      sys->Change_Mount_Read_Only(false);
	      if (ven)
		ven->Change_Mount_Read_Only(false);
	    }
	}
      else if (DataManager::GetIntValue("tw_mount_system_ro") == 1)
	{
	  // Do nothing, user selected to leave system read only
	}
      else
	{
	  sys->Change_Mount_Read_Only(false);
	  if (ven)
	    ven->Change_Mount_Read_Only(false);
	}
    }
#endif
  twrpAdbBuFifo *adb_bu_fifo = new twrpAdbBuFifo();
  adb_bu_fifo->threadAdbBuFifo();

  // LOGINFO("OrangeFox: Reloading theme to apply generated theme on sdcard - again...\n");

// run the postrecoveryboot script here
TWFunc::RunFoxScript("/sbin/postrecoveryboot.sh");
#ifndef OF_DEVICE_WITHOUT_PERSIST
DataManager::RestorePasswordBackup();
#endif

#ifdef FOX_OLD_DECRYPT_RELOAD
  LOGINFO("Using R10 way to reload theme.\n");
  if (DataManager::GetStrValue("used_custom_encryption") == "1") {
     if (TWFunc::Path_Exists(Fox_Home + "/.theme") || TWFunc::Path_Exists(Fox_Home + "/.navbar")) // using custom themes
         PageManager::RequestReload();
  }
#else
  if (DataManager::GetStrValue("data_decrypted") == "1")
  {
	//[f/d] Start UI using reapply_settings page (executed on recovery startup)
	if (TWFunc::Path_Exists(Fox_Home + "/.theme") || TWFunc::Path_Exists(Fox_Home + "/.navbar")) {
  		DataManager::SetValue("of_reload_back", "main");
		PageManager::RequestReload();
    	gui_startPage("reapply_settings", 1, 0);
	} else {
		gui_start();
    }
  }
  else
#endif
	gui_start(); // Launch the main GUI

#ifndef TW_OEM_BUILD

  // Disable flashing of stock recovery
  TWFunc::Disable_Stock_Recovery_Replace();
#endif

	// Reboot
	TWFunc::Update_Intent_File(Send_Intent);
	delete adb_bu_fifo;
	TWFunc::Update_Log_File();
	gui_msg(Msg("rebooting=Rebooting..."));
	string Reboot_Arg;
	DataManager::GetValue("tw_reboot_arg", Reboot_Arg);
	if (Reboot_Arg == "recovery")
		TWFunc::tw_reboot(rb_recovery);
	else if (Reboot_Arg == "poweroff")
		TWFunc::tw_reboot(rb_poweroff);
	else if (Reboot_Arg == "bootloader")
		TWFunc::tw_reboot(rb_bootloader);
	else if (Reboot_Arg == "download")
		TWFunc::tw_reboot(rb_download);
	else if (Reboot_Arg == "edl")
		TWFunc::tw_reboot(rb_edl);
	else
		TWFunc::tw_reboot(rb_system);

  return 0;
}

