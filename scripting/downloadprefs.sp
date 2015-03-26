/**
 * Download Preferences
 * Author(s): nosoop
 * File:  downloadprefs.sp
 * Description:	 Allows clients to select categories of files to download.
 * License:	 MIT License
 */

#pragma semicolon 1
#include <sourcemod>

#define PLUGIN_VERSION			"0.7.2"
public Plugin:myinfo = {
	name = "Download Preferences",
	author = "nosoop",
	description = "Client download preferences",
	version = PLUGIN_VERSION,
	url = "http://github.com/nosoop/SM-DownloadPrefs"
}

#define INVALID_DPREFS_ID -1 // Invalid external identifier (what plugins use to communicate with the library)
#define INVALID_DOWNLOAD_CATEGORY -1 // Invalid internal identifier (what the library uses to communicate with the backend)
#define MAX_SQL_QUERY_LENGTH 512
#define MAX_URL_LENGTH 256

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

// Database name and related handle
#define DATABASE_NAME "downloadprefs"
new Handle:g_hDatabase = INVALID_HANDLE;

// ConVar handles
new Handle:g_hCDownloadURL = INVALID_HANDLE, // sv_downloadurl
	Handle:g_hCDPrefURL = INVALID_HANDLE; // sm_dprefs_downloadurl

// TODO allocate new g_rgDownloadPreferences[MAXPLAYERS][MAX_DOWNLOAD_PREFERENCES];

// TODO perform plugin / category validation

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
	CreateNative("RegClientDownloadFile", Native_RegClientDownloadFile);
	CreateNative("SetClientDownloadPreference", Native_SetClientDownloadPreference);
	CreateNative("GetClientDownloadPreference", Native_GetClientDownloadPreference);
	CreateNative("ClientHasDownloadPreference", Native_ClientHasDownloadPreference);
	
	// Raw access methods
	CreateNative("SetRawDownloadPreference", Native_SetRawDownloadPreference);
	CreateNative("GetRawDownloadPreference", Native_GetRawDownloadPreference);
	CreateNative("HasRawDownloadPreference", Native_HasRawDownloadPreference);
	
	// Unstable methods
	CreateNative("RawCategoryInfo", Native_RawCategoryInfo);
	CreateNative("GetActiveCategories", Native_GetActiveCategories);
	CreateNative("CategoryToIdentifier", Native_CategoryToIdentifier);

	g_hDatabase = GetDatabase();
	
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
	new Handle:hQuery = INVALID_HANDLE, categoryid;
	decl String:sQuery[MAX_SQL_QUERY_LENGTH];
	
	new String:safeCategory[128];
	SQL_EscapeString(g_hDatabase, category, safeCategory, sizeof(safeCategory));
	
	// TODO Proper fix for query sanitization and abstraction
	Format(sQuery, sizeof(sQuery), "SELECT categoryid FROM categories WHERE categoryname='%s'",
			safeCategory);
	hQuery = SQL_Query(g_hDatabase, sQuery);
	
	// Category does not exist; create it.
	if (SQL_GetRowCount(hQuery) == 0 && CloseHandle(hQuery)) {
		new String:error[4];
		new Handle:hStmt = SQL_PrepareQuery(g_hDatabase,
				"INSERT OR REPLACE INTO categories (categoryid, categoryname, categorydesc, enabled) VALUES (NULL, ?, ?, ?)",
				error, sizeof(error));
		
		SQL_BindParamString(hStmt, 0, category, false);
		SQL_BindParamString(hStmt, 1, description, false);
		SQL_BindParamInt(hStmt, 2, enabled);
		SQL_Execute(hStmt);
		CloseHandle(hStmt);
	}
	
	Format(sQuery, sizeof(sQuery), "SELECT categoryid FROM categories WHERE categoryname='%s'",
			safeCategory);
	hQuery = SQL_Query(g_hDatabase, sQuery);
	SQL_FetchRow(hQuery);
	categoryid = SQL_FetchInt(hQuery, 0);
	
	CloseHandle(hQuery);
	
	return DownloadCategoryAdded(categoryid);
}

public Native_RegClientDownloadCategory(Handle:hPlugin, nParams) {
	decl String:category[512], String:description[512];
	
	GetNativeString(1, category, sizeof(category));
	GetNativeString(2, description, sizeof(description));
	new bool:bDefault = GetNativeCell(3);
	
	return RegClientDownloadCategory(category, description, bDefault);
}

/**
 * Registers a file to a category.
 */
RegClientDownloadFile(id, const String:filepath[]) {
	if (!IsValidDownloadCategory(id)) {
		ThrowError("Invalid id %d", id);
	}
	decl String:sQuery[MAX_SQL_QUERY_LENGTH];
	Format(sQuery, sizeof(sQuery),
			"INSERT OR REPLACE INTO files (categoryid, filepath) VALUES (%d, '%s')",
			g_rgiCategories[id], filepath);
	SQL_FastQuery(g_hDatabase, sQuery);
}

public Native_RegClientDownloadFile(Handle:hPlugin, nParams) {
	new id = GetNativeCell(1);
	decl String:filepath[PLATFORM_MAX_PATH]; GetNativeString(2, filepath, sizeof(filepath));
	
	// TODO perform plugin validation
	RegClientDownloadFile(id, filepath);
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
	
	// TODO perform plugin validation
	SetClientDownloadPreference(client, id, enabled);
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
	
	// TODO perform plugin validation
	return GetClientDownloadPreference(client, id);
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
	return ClientHasDownloadPreference(client, id, result);
}

/**
 * Gets the description of the download category.
 */
bool:RawCategoryInfo(categoryid, String:title[], maxTitleLength, String:description[], maxDescLength) {
	decl String:sQuery[MAX_SQL_QUERY_LENGTH];
	new Handle:hQuery = INVALID_HANDLE;
	new bool:bHasRows;
	
	Format(sQuery, sizeof(sQuery), "SELECT categoryname, categorydesc FROM categories WHERE categoryid=%d",
			categoryid);
	hQuery = SQL_Query(g_hDatabase, sQuery);
	
	if ((bHasRows = (SQL_GetRowCount(hQuery) > 0))) {
		SQL_FetchRow(hQuery);
		SQL_FetchString(hQuery, 0, title, maxTitleLength);
		SQL_FetchString(hQuery, 1, description, maxDescLength);
	}
	
	CloseHandle(hQuery);
	return bHasRows;
}

public Native_RawCategoryInfo(Handle:hPlugin, nParams) {
	new categoryid = GetNativeCell(1), maxTitleLength = GetNativeCell(3), maxDescLength = GetNativeCell(5);
	new String:title[maxTitleLength], String:description[maxDescLength];
	
	new bool:bResult = RawCategoryInfo(categoryid, title, maxTitleLength, description, maxDescLength);
	
	SetNativeString(2, title, maxTitleLength);
	SetNativeString(3, description, maxDescLength);
	
	return bResult;
}

/**
 * Adds the specified category to the active category list.
 */
_:DownloadCategoryAdded(categoryid) {
	new bool:bFound = false;
	
	for (new i = 0; i < g_nDownloadPrefs; i++) {
		bFound |= (categoryid == GetCategoryIdentifier(i));
		if (bFound) {
			// Category already exists
			return i;
		}
	}
	
	if (g_nDownloadPrefs < MAX_DOWNLOAD_PREFERENCES) {
		SetCategoryIdentifier(g_nDownloadPrefs, categoryid);
		return g_nDownloadPrefs++;
	}
	return INVALID_DPREFS_ID;
}

/**
 * Checks if the download category is not invalid.
 */
bool:IsValidDownloadCategory(id) {
	return GetCategoryIdentifier(id) != INVALID_DOWNLOAD_CATEGORY;
}

public Native_GetActiveCategories(Handle:hPlugin, nParams) {
	new size = GetNativeCell(2), start = GetNativeCell(3), nCategories;
	new categoryids[size];
	
	for (new i = start; i < g_nDownloadPrefs; i++) {
		if (IsValidDownloadCategory(i)) {
			categoryids[nCategories++] = GetCategoryIdentifier(i);
		}
	}
	
	SetNativeArray(1, categoryids, size);
	
	return nCategories;
}

/**
 * Provides raw access to update the database for the specified SteamID.
 */
SetRawDownloadPreference(steamid, categoryid, bool:enabled) {
	decl String:sQuery[MAX_SQL_QUERY_LENGTH];
	
	if (HasRawDownloadPreference(steamid, categoryid)) {
		// Update existing entry.
		Format(sQuery, sizeof(sQuery), "UPDATE downloadprefs SET enabled = %d WHERE sid3 = %d AND categoryid = %d",
				_:enabled, steamid, categoryid);
	} else {
		// Create new entry.
		Format(sQuery, sizeof(sQuery), "INSERT INTO downloadprefs (sid3, categoryid, enabled) VALUES (%d, %d, %d)",
				steamid, categoryid, _:enabled);
	}
	SQL_FastQuery(g_hDatabase, sQuery);
}

public Native_SetRawDownloadPreference(Handle:hPlugin, nParams) {
	new steamid = GetNativeCell(1), categoryid = GetNativeCell(2), bool:enabled = GetNativeCell(3);
	SetRawDownloadPreference(steamid, categoryid, enabled);
}

/**
 * Grants raw access to retrieve the download preference for the specified SteamID and category.
 */
bool:GetRawDownloadPreference(steamid, categoryid) {
	decl String:sQuery[MAX_SQL_QUERY_LENGTH];
	new bool:bPreferenceEnabled;
	
	if (!HasRawDownloadPreference(steamid, categoryid, bPreferenceEnabled)) {
		// Default preference for category
		Format(sQuery, sizeof(sQuery), "SELECT enabled FROM categories WHERE categoryid=%d",
				categoryid);
		bPreferenceEnabled = bool:SQL_QuerySingleRowInt(g_hDatabase, sQuery);
	}
	
	return bPreferenceEnabled;
}

public Native_GetRawDownloadPreference(Handle:hPlugin, nParams) {
	new steamid = GetNativeCell(1), categoryid = GetNativeCell(2);
	return GetRawDownloadPreference(steamid, categoryid);
}

/**
 * Checks if a SteamID has a preference set for a category.
 */
bool:HasRawDownloadPreference(steamid, categoryid, &any:result = 0) {
	decl String:sQuery[MAX_SQL_QUERY_LENGTH];

	new bool:bHasRows;
	new Handle:hQuery = INVALID_HANDLE;
	Format(sQuery, sizeof(sQuery), "SELECT enabled FROM downloadprefs WHERE sid3=%d AND categoryid=%d",
			steamid, categoryid);
	hQuery = SQL_Query(g_hDatabase, sQuery);
	
	if ((bHasRows = (SQL_GetRowCount(hQuery) > 0))) {
		SQL_FetchRow(hQuery);
		result = bool:SQL_FetchInt(hQuery, 0);
	}
	
	CloseHandle(hQuery);
	return bHasRows;
}

public Native_HasRawDownloadPreference(Handle:hPlugin, nParams) {
	new steamid = GetNativeCell(1), categoryid = GetNativeCell(2), bool:result;
	
	new bool:response = HasRawDownloadPreference(steamid, categoryid, result);
	SetNativeCellRef(3, result);
	
	return response;
}

/**
 * Converts a categoryid to an id.
 */
public Native_CategoryToIdentifier(Handle:hPlugin, nParams) {
	new categoryid = GetNativeCell(1);
	for (new i = 0; i < g_nDownloadPrefs; i++) {
		if (categoryid == GetCategoryIdentifier(i)) {
			// Category already exists
			return i;
		}
	}
	return INVALID_DPREFS_ID;
}

/**
 * Runs a query, returning the first integer from the first row.
 */
_:SQL_QuerySingleRowInt(Handle:database, const String:query[]) {
	new result;
	new Handle:hQuery = SQL_Query(database, query);
	
	result = SQL_FetchInt(hQuery, 0);
	CloseHandle(hQuery);
	
	return result;
}

/**
 * Wrapper around the data array.
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
	return g_rgiCategories[slot][DCS_Owner];
}

SetCategoryAccess(slot, DownloadPrefsAccess:access) {
	g_rgiCategories[slot][DCS_AccessLevel] = _:access;
}

DownloadPrefsAccess:GetCategoryAccess(slot) {
	return g_rgiCategories[slot][DCS_AccessLevel];
}

ClearCategory(slot) {
	SetCategoryIdentifier(slot, INVALID_DOWNLOAD_CATEGORY);
	SetCategoryOwner(slot, INVALID_HANDLE);
	SetCategoryAccess(slot, DownloadPrefsAccess_Private);
}

/**
 * Reads the database configuration.
 */
Handle:GetDatabase() {	
	new Handle:hDatabase = INVALID_HANDLE;
	
	if (SQL_CheckConfig(DATABASE_NAME)) {
		decl String:sErrorBuffer[256];
		if ( (hDatabase = SQL_Connect(DATABASE_NAME, true, sErrorBuffer, sizeof(sErrorBuffer))) == INVALID_HANDLE ) {
			SetFailState("[downloadprefs] Could not connect to database: %s", sErrorBuffer);
		} else {
			return hDatabase;
		}
	} else {
		SetFailState("[downloadprefs] Could not find configuration %s to load database.", DATABASE_NAME);
	}
	return INVALID_HANDLE;
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
