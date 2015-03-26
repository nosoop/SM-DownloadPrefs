/**
 * Download Preferences Loader
 * Author(s): nosoop
 * File:  downloadprefs_loader.sp
 * Description:	 Allows server administrators to add categories and files through a text-based configuration
 * License:	 MIT License
 */

#pragma semicolon 1
#include <sourcemod>
#undef REQUIRE_EXTENSIONS
#include <downloadprefs>
#define REQUIRE_EXTENSIONS

#define PLUGIN_VERSION			"0.1.0"		// Plugin version.
public Plugin:myinfo = {
	name = "Download Preferences Loader",
	author = "nosoop",
	description = "Loads categories from a simple configuration file.",
	version = PLUGIN_VERSION,
	url = "http://github.com/nosoop/SM-DownloadPrefs"
}

#define DOWNLOADPREFS_CONFIG "data/downloadprefs.txt"
#define DOWNLOADPREFS_LIBRARY "downloadprefs"

new bool:g_bDPrefsLoaded = false;

public OnPluginStart() {
	RegAdminCmd("sm_dprefs_loader_refresh", ConCmd_ReloadCategories, ADMFLAG_ROOT, "Reparses the download preference file.");
}

public OnPluginEnd() {
	if (g_bDPrefsLoaded) {
		UnregClientDownloadCategories();
	}
}

public Action:ConCmd_ReloadCategories(client, nArgs) {
	LoadCategories();
	PrintToChat(client, "[SM] The download preference file has been reloaded.");
	return Plugin_Handled;
}

LoadCategories() {
	decl String:sCategoryFilePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sCategoryFilePath, sizeof(sCategoryFilePath), DOWNLOADPREFS_CONFIG);
	
	if (FileExists(sCategoryFilePath)) {
		new Handle:hCategoryFile = OpenFile(sCategoryFilePath, "r");
		if (hCategoryFile != INVALID_HANDLE) {
			new String:sConfigLine[256];
			
			new iCategoryIdentifier = -1;
			new String:sCategoryInfo[2][128];
			while (ReadFileLine(hCategoryFile, sConfigLine, sizeof(sConfigLine))) {
				TrimString(sConfigLine);
				if (strlen(sConfigLine) == 0 || FindCharInString(sConfigLine, '#') == 0) {
					continue;
				}
				
				if (StrContains(sConfigLine, "-- ") == 0) {
					ExplodeString(sConfigLine[3], ":", sCategoryInfo, sizeof(sCategoryInfo), sizeof(sCategoryInfo[]), true);
					
					// Assume default of not downloading
					iCategoryIdentifier = RegClientDownloadCategory(sCategoryInfo[0], sCategoryInfo[1], false);
					PrintToServer("Registered category %s, given identifier %d", sCategoryInfo[0], iCategoryIdentifier);
					sCategoryInfo[0] = "";
					sCategoryInfo[1] = "";
				} else {
					if (FileExists(sConfigLine, true) && iCategoryIdentifier != -1) {
						RegClientDownloadFile(iCategoryIdentifier, sConfigLine);
						PrintToServer("Registered file %s", sConfigLine);
					} else {
						PrintToServer("Unreadable line %s", sConfigLine);
					}
				}
				
				// Check if file exists in valvefs
				// Call RegClientDownloadFile
			}
			CloseHandle(hCategoryFile);
		}
	}
}

public OnAllPluginsLoaded() {
	new bool:bLastState = g_bDPrefsLoaded;
	OnDPrefsStateCheck((g_bDPrefsLoaded = LibraryExists(DOWNLOADPREFS_LIBRARY)) != bLastState);
}

public OnLibraryRemoved(const String:name[]) {
	new bool:bLastState = g_bDPrefsLoaded;
	OnDPrefsStateCheck((g_bDPrefsLoaded &= !StrEqual(name, DOWNLOADPREFS_LIBRARY)) != bLastState);
}

public OnLibraryAdded(const String:name[]) {
	new bool:bLastState = g_bDPrefsLoaded;
	OnDPrefsStateCheck((g_bDPrefsLoaded |= StrEqual(name, DOWNLOADPREFS_LIBRARY)) != bLastState);
}

public OnDPrefsStateCheck(bHasChanged) {
	if (bHasChanged) {
		if (g_bDPrefsLoaded) {
			LoadCategories();
		}
	}
}
