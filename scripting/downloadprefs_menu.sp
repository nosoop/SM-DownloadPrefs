/**
 * Download Preferences Client Menu
 * Author(s): nosoop
 * File:  downloadprefs_menu.sp
 * Description:	 Provides clients with a menu to select which files they will download.
 * License:	 MIT License
 */

#pragma semicolon 1

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <downloadprefs>

#define PLUGIN_VERSION          "0.3.1"     // Plugin version.

public Plugin:myinfo = {
    name = "Download Preferences Client Menu",
    author = "nosoop",
    description = "Allow clients to toggle download preferences.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop/SM-DownloadPrefs"
}

/**
 * WARNING: Total hackjob below.
 */

new bool:g_bDPrefsLoaded = false;

public OnPluginStart() {
	RegConsoleCmd("sm_downloads", ConCmd_OpenDownloadPrefMenu);
}

public Action:ConCmd_OpenDownloadPrefMenu(iClient, nArgs) {
	if (!g_bDPrefsLoaded) {
		PrintToConsole(iClient, "The downloadprefs library is not available.");
		return Plugin_Handled;
	}
	
	new category[128];
	new size = GetAccessibleCategories(category, sizeof(category));
	
	new Handle:hMenu = CreateMenu(MenuHandler_DownloadPref, MENU_ACTIONS_ALL);
	SetMenuTitle(hMenu, "Download Preferences");
	
	new String:title[128], String:desc[1], String:id[4], String:display[64];
	for (new i = 0; i < size; i++) {
		if (GetCategoryInfo(category[i], title, sizeof(title), desc, sizeof(desc))) {
			new bool:bPreference = GetClientDownloadPreference(iClient, category[i]);
			
			Format(display, sizeof(display), "[%s] %s", bPreference ? "x" : "_", title);
			IntToString(category[i], id, sizeof(id));
			
			AddMenuItem(hMenu, id, display);
		}
	}
	
	DisplayMenu(hMenu, iClient, 10);

	return Plugin_Handled;
}

public MenuHandler_DownloadPref(Handle:hMenu, MenuAction:iAction, param1, param2) {
	if (!g_bDPrefsLoaded) {
		CloseHandle(hMenu);
		return 0;
	}

	decl String:sCategory[4];
	new String:title[128], String:desc[1], String:display[64];
	
	// This stuff's horribly inefficent, but it'll have to do for now.
	switch (iAction) {
		case MenuAction_Select: {
			new iClient = param1, item = param2;
			GetMenuItem(hMenu, item, sCategory, sizeof(sCategory));
			new cid = StringToInt(sCategory);
			
			new bool:bPreference = GetClientDownloadPreference(iClient, cid);
			SetClientDownloadPreference(iClient, cid, !bPreference);
			
			DisplayMenu(hMenu, iClient, 10);
		}
		case MenuAction_DisplayItem: {
			new iClient = param1, item = param2;
			GetMenuItem(hMenu, item, sCategory, sizeof(sCategory));
			new category = StringToInt(sCategory);
			
			if (GetCategoryInfo(category, title, sizeof(title), desc, sizeof(desc))) {
				new bool:bPreference = GetClientDownloadPreference(iClient, category);
				Format(display, sizeof(display), "[%s] %s", bPreference ? "x" : "_", title);
				
				return RedrawMenuItem(display);
			}
		}
		case MenuAction_End: {
			new iMenuEndReason = param1;
			if (iMenuEndReason == MenuEnd_Cancelled) {
				CloseHandle(hMenu);
			}
		}
	}
	return 0;
}

/**
 * Checks for the existence of the downloadprefs library.
 */
public OnAllPluginsLoaded() { g_bDPrefsLoaded = LibraryExists("downloadprefs"); }
public OnLibraryRemoved(const String:name[]) { g_bDPrefsLoaded &= !StrEqual(name, "downloadprefs"); }
public OnLibraryAdded(const String:name[]) { g_bDPrefsLoaded |= StrEqual(name, "downloadprefs"); }
