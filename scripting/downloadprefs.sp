/**
 * Download Preferences
 * Author(s): nosoop
 * File:  downloadprefs.sp
 * Description:	 Allows clients to select categories of files to download.
 * License:	 MIT License
 */

#pragma semicolon 1
#include <sourcemod>

// Compile with SQLite support by default.
#include "downloadprefs/db-sqlite.sp"

#define PLUGIN_VERSION			"0.8.1"
public Plugin:myinfo = {
	name = "Download Preferences",
	author = "nosoop",
	description = "Client download preferences",
	version = PLUGIN_VERSION,
	url = "http://github.com/nosoop/SM-DownloadPrefs"
}

#define INVALID_DPREFS_ID -1 // Invalid external identifier (what plugins use to communicate with the library)
#define INVALID_DOWNLOAD_CATEGORY -1 // Invalid internal identifier (what the library uses to communicate with the backend)
#define MAX_URL_LENGTH 256

#define NATIVEERROR_NOPERMISSION 1

enum DownloadPrefsAccess {
	DownloadPrefsAccess_Public,
	DownloadPrefsAccess_Protected,
	DownloadPrefsAccess_Private,
}

enum CategorySettings {
	DCS_CategoryIdentifier = 0,
	DCS_Owner,
	DCS_AccessLevel,
	CATEGORYSETTINGS_SIZE
}

// List of categories that have been registered in this session
#define MAX_DOWNLOAD_PREFERENCES 64
new g_rgiCategories[MAX_DOWNLOAD_PREFERENCES][CATEGORYSETTINGS_SIZE], g_nDownloadPrefs;

// ConVar handles
new Handle:g_hCDownloadURL = INVALID_HANDLE, // sv_downloadurl
	Handle:g_hCDPrefURL = INVALID_HANDLE; // sm_dprefs_downloadurl

// TODO allocate new g_rgDownloadPreferences[MAXPLAYERS][MAX_DOWNLOAD_PREFERENCES];

public OnPluginStart() {
	CreateConVar("sm_dprefs_version", PLUGIN_VERSION, _, FCVAR_PLUGIN | FCVAR_NOTIFY);
	
	g_nDownloadPrefs = 0;
	for (new i = 0; i < MAX_DOWNLOAD_PREFERENCES; i++) {
		ClearCategory(i);
	}
	
	// Hook to set redirect downloadurl.  If blank, the transmission of sv_downloadurl to the client is not changed.
	g_hCDownloadURL = FindConVar("sv_downloadurl");
	g_hCDPrefURL = CreateConVar("sm_dprefs_downloadurl", "", "Download URL to send to the client.  See README for details.", FCVAR_PLUGIN | FCVAR_SPONLY);

	AutoExecConfig(true);
}

public OnPluginEnd() {
	CloseHandle(g_hDatabase);
}

public APLRes:AskPluginLoad2(Handle:hMySelf, bool:bLate, String:strError[], iMaxErrors) {
	RegPluginLibrary("downloadprefs");
	
	CreateNative("RegClientDownloadCategory", Native_RegClientDownloadCategory);
	CreateNative("UnregClientDownloadCategories", Native_UnregClientDownloadCategories);
	
	CreateNative("RegClientDownloadFile", Native_RegClientDownloadFile);
	CreateNative("SetClientDownloadPreference", Native_SetClientDownloadPreference);
	CreateNative("GetClientDownloadPreference", Native_GetClientDownloadPreference);
	CreateNative("ClientHasDownloadPreference", Native_ClientHasDownloadPreference);
	
	CreateNative("GetCategoryInfo", Native_GetCategoryInfo);
	CreateNative("GetAccessibleCategories", Native_GetAccessibleCategories);

	PrepareDatabase();
	
	return APLRes_Success;
}

/**
 * Sends a custom download URL when the client is connecting.
 * This occurs every time the client reconnects (via map change, etc.)
 */
public OnClientAuthorized(client, const String:auth[]) {
	if (!IsFakeClient(client)) {
		SendCustomDownloadURL(client);
	}
}

SendCustomDownloadURL(client) {
	new iSteamID3 = GetSteamAccountID(client);
	new String:sClientDownloadURL[MAX_URL_LENGTH];
	GetConVarString(g_hCDPrefURL, sClientDownloadURL, sizeof(sClientDownloadURL));
	
	// TODO strip trailing slash off of sm_dprefs_downloadurl?
	
	if (strlen(sClientDownloadURL) > 0) {
		new String:sSteamID3[32];
		IntToString(iSteamID3, sSteamID3, sizeof(sSteamID3));
		ReplaceString(sClientDownloadURL, sizeof(sClientDownloadURL), "$STEAMID", sSteamID3);
		SendConVarValue(client, g_hCDownloadURL, sClientDownloadURL);
	}
}

/**
 * Resets the download URL to the server-supplied value once the client is fully in-game.
 * This occurs after the client has performed any fast download requests.
 */
public OnClientPostAdminCheck(client) {
	if (!IsFakeClient(client)) {
		new String:sDefaultDownloadURL[MAX_URL_LENGTH];
		GetConVarString(g_hCDownloadURL, sDefaultDownloadURL, sizeof(sDefaultDownloadURL));
		SendConVarValue(client, g_hCDownloadURL, sDefaultDownloadURL);
	}
}

/**
 * Registers a group of files to download.
 * Store the category plus description into the database if nonexistent, 
 * returning an ID to the corresponding category.
 */
_:RegClientDownloadCategory(const String:category[], const String:description[], bool:enabled = true) {
	return DownloadCategoryAdded(RawCreateCategory(category, description, enabled));
}

public Native_RegClientDownloadCategory(Handle:hPlugin, nParams) {
	decl String:category[512], String:description[512];
	
	GetNativeString(1, category, sizeof(category));
	GetNativeString(2, description, sizeof(description));
	new bool:bDefault = GetNativeCell(3),
		DownloadPrefsAccess:access = nParams > 3 ? GetNativeCell(4) : DownloadPrefsAccess_Public;
	
	new id = RegClientDownloadCategory(category, description, bDefault);
	
	if (id == INVALID_DPREFS_ID) {
		return INVALID_DPREFS_ID;
	} else if (GetCategoryAccess(id) == DownloadPrefsAccess_Public) {
		return id;
	} else if (GetCategoryOwner(id) == INVALID_HANDLE) {
		// Uninitialized category
		SetCategoryOwner(id, hPlugin);
		SetCategoryAccess(id, access);
		return id;
	}
	
	// Non-public with a different owner
	return INVALID_DPREFS_ID;
}

public Native_UnregClientDownloadCategories(Handle:hPlugin, nParams) {
	for (new i = 0; i < g_nDownloadPrefs; i++) {
		if (GetCategoryOwner(i) == hPlugin) {
			ClearCategory(i);
		}
	}
}

/**
 * Registers a file to a category.
 */
RegClientDownloadFile(id, const String:filepath[]) {
	if (!IsValidDownloadCategory(id)) {
		ThrowError("Invalid id %d", id);
	}
	RawAssignFileCategory(GetCategoryIdentifier(id), filepath);
}

public Native_RegClientDownloadFile(Handle:hPlugin, nParams) {
	new id = GetNativeCell(1);
	decl String:filepath[PLATFORM_MAX_PATH]; GetNativeString(2, filepath, sizeof(filepath));
	
	if (PluginHasWriteAccess(hPlugin, id)) {
	RegClientDownloadFile(id, filepath);
	} else {
		ThrowNativeError(NATIVEERROR_NOPERMISSION, "Plugin %d is not allowed to add files to category identifier %d", hPlugin, id);
	}
}

/**
 * Stores the client's download preference.
 */
SetClientDownloadPreference(client, id, bool:enabled) {
	if (!IsValidDownloadCategory(id)) {
		ThrowError("Invalid id %d", id);
	}
	SetRawDownloadPreference(GetSteamAccountID(client), GetCategoryIdentifier(id), enabled);
}

public Native_SetClientDownloadPreference(Handle:hPlugin, nParams) {
	new client = GetNativeCell(1), id = GetNativeCell(2), bool:enabled = GetNativeCell(3);
	
	if (PluginHasWriteAccess(hPlugin, id)) {
		SetClientDownloadPreference(client, id, enabled);
	} else {
		ThrowNativeError(NATIVEERROR_NOPERMISSION, "Plugin %d is not allowed to write preference to category identifier %d", hPlugin, id);
	}
}

/**
 * Retrieves a client's download preference.  If non-existent, will return the default setting.
 * A client will keep their existing download preference until a map change or reconnect.
 */
bool:GetClientDownloadPreference(client, id) {
	if (!IsValidDownloadCategory(id)) {
		SetFailState("Could not get download preference for ID %d", id);
	}
	return GetRawDownloadPreference(GetSteamAccountID(client), GetCategoryIdentifier(id));
}

public Native_GetClientDownloadPreference(Handle:hPlugin, nParams) {
	new client = GetNativeCell(1), id = GetNativeCell(2);
	
	if (PluginHasReadAccess(hPlugin, id)) {
		return GetClientDownloadPreference(client, id);
	} else {
		// Category is private access.
		ThrowNativeError(NATIVEERROR_NOPERMISSION, "Plugin %d is not allowed to read preferences from category identifier %d", hPlugin, id);
		return false;
	}
}

/**
 * Checks whether or not the client has their own download preference set.
 */
bool:ClientHasDownloadPreference(client, id, &any:result = 0) {
	if (!IsValidDownloadCategory(id)) {
		SetFailState("Could not check download preference for %N (ID %d)", client, id);
	}
	return HasRawDownloadPreference(GetSteamAccountID(client), GetCategoryIdentifier(id), result);
}

public Native_ClientHasDownloadPreference(Handle:hPlugin, nParams) {
	new client = GetNativeCell(1), id = GetNativeCell(2), result = GetNativeCellRef(3);
	
	if (PluginHasReadAccess(hPlugin, id)) {
		return ClientHasDownloadPreference(client, id, result);
	} else {
		// Category is private access.
		ThrowNativeError(NATIVEERROR_NOPERMISSION, "Plugin %d is not allowed to read preferences from category identifier %d", hPlugin, id);
		return false;
	}
}

/**
 * Gets the description of the download category.
 */
bool:GetCategoryInfo(id, String:title[], maxTitleLength, String:description[], maxDescLength) {
	return RawGetCategoryInfo(GetCategoryIdentifier(categoryid), title, maxTitleLength, description, maxDescLength);
}

public Native_GetCategoryInfo(Handle:hPlugin, nParams) {
	new id = GetNativeCell(1), maxTitleLength = GetNativeCell(3), maxDescLength = GetNativeCell(5);
	new String:title[maxTitleLength], String:description[maxDescLength];
	
	new bool:bResult = GetCategoryInfo(id, title, maxTitleLength, description, maxDescLength);
	
	SetNativeString(2, title, maxTitleLength);
	SetNativeString(3, description, maxDescLength);
	
	return bResult;
}

/**
 * Adds the specified category to the active category list.
 */
_:DownloadCategoryAdded(categoryid) {
	new bool:bFound = false,
		iFree = MAX_DOWNLOAD_PREFERENCES;
	
	for (new i = 0; i < g_nDownloadPrefs; i++) {
		bFound |= (categoryid == GetCategoryIdentifier(i));
		if (bFound) {
			// Category already exists
			return i;
		}
		if (GetCategoryIdentifier(i) == INVALID_DOWNLOAD_CATEGORY) {
			iFree = i < iFree ? i : iFree;
		}
	}
	
	if (g_nDownloadPrefs < MAX_DOWNLOAD_PREFERENCES) {
		if (iFree < MAX_DOWNLOAD_PREFERENCES) {
			SetCategoryIdentifier(iFree, categoryid);
			return iFree;
		} else {
			SetCategoryIdentifier(g_nDownloadPrefs, categoryid);
			return g_nDownloadPrefs++;
		}
	}
	return INVALID_DPREFS_ID;
}

/**
 * Checks if the download category is not invalid.
 */
bool:IsValidDownloadCategory(id) {
	return GetCategoryIdentifier(id) != INVALID_DOWNLOAD_CATEGORY;
}

public Native_GetAccessibleCategories(Handle:hPlugin, nParams) {
	new size = GetNativeCell(2), start = GetNativeCell(3), nCategories;
	new categoryids[size];
	
	for (new i = start; i < g_nDownloadPrefs; i++) {
		if (IsValidDownloadCategory(i) && GetCategoryAccess(i) == DownloadPrefsAccess_Public) {
			categoryids[nCategories++] = i;
		}
	}
	
	SetNativeArray(1, categoryids, size);
	
	return nCategories;
}

/**
 * Wrapper functions around the data array.
 */

SetCategoryIdentifier(slot, id) {
	g_rgiCategories[slot][DCS_CategoryIdentifier] = id;
}

_:GetCategoryIdentifier(slot) {
	return g_rgiCategories[slot][DCS_CategoryIdentifier];
}

SetCategoryOwner(slot, Handle:hPlugin) {
	g_rgiCategories[slot][DCS_Owner] = _:hPlugin;
}

Handle:GetCategoryOwner(slot) {
	return Handle:g_rgiCategories[slot][DCS_Owner];
}

SetCategoryAccess(slot, DownloadPrefsAccess:access) {
	g_rgiCategories[slot][DCS_AccessLevel] = _:access;
}

DownloadPrefsAccess:GetCategoryAccess(slot) {
	return DownloadPrefsAccess:g_rgiCategories[slot][DCS_AccessLevel];
}

ClearCategory(slot) {
	SetCategoryIdentifier(slot, INVALID_DOWNLOAD_CATEGORY);
	SetCategoryOwner(slot, INVALID_HANDLE);
	SetCategoryAccess(slot, DownloadPrefsAccess_Private);
}

bool:PluginHasReadAccess(Handle:hPlugin, slot) {
	return GetCategoryOwner(slot) == hPlugin || GetCategoryAccess(slot) != DownloadPrefsAccess_Private;
}

bool:PluginHasWriteAccess(Handle:hPlugin, slot) {
	return GetCategoryOwner(slot) == hPlugin || GetCategoryAccess(slot) == DownloadPrefsAccess_Public;
}

/**
 * Flow to check if a download is allowed.
 * When a client is authorized: -> Send custom virtual fastdl directory data
 * When a client downloads a file: ->
 *	  - Get SteamID3 from query string
 *	  - Get 'categoryid' by 'filepath' in table files (filepath obtained in query string),
 *	  - Get 'enabled' by 'sid3' and 'category' in downloadprefs,
 *	  - (If not found, get 'enabled' by 'categoryid' in table categories),
 *	  - If enabled, allow the download, otherwise redirect / 404.
 */
