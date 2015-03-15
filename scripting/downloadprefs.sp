/**
 * Download Preferences
 * Author(s): nosoop
 * File:  downloadprefs.sp
 * Description:	 Allows clients to select categories of files to download.
 * License:	 MIT License
 */

#pragma semicolon 1
#include <sourcemod>

#define PLUGIN_VERSION			"0.6.1"

public Plugin:myinfo = {
	name = "Download Preferences",
	author = "nosoop",
	description = "Client download preferences",
	version = PLUGIN_VERSION,
	url = "http://github.com/nosoop/SM-DownloadPrefs"
}

#define INVALID_DOWNLOAD_CATEGORY -1
#define MAX_SQL_QUERY_LENGTH 512
#define MAX_URL_LENGTH 256

#define MAX_DOWNLOAD_PREFERENCES 64
new g_rgiDownloadPrefs[MAX_DOWNLOAD_PREFERENCES], g_nDownloadPrefs;

#define DATABASE_NAME			"downloadprefs" // Database name in config
new Handle:g_hDatabase = INVALID_HANDLE;

// ConVar handles
new Handle:g_hCDownloadURL = INVALID_HANDLE, // sv_downloadurl
	Handle:g_hCDPrefURL = INVALID_HANDLE; // sm_dprefs_downloadurl

public OnPluginStart() {
	CreateConVar("sm_dprefs_version", PLUGIN_VERSION, _, FCVAR_PLUGIN | FCVAR_NOTIFY);
	
	g_nDownloadPrefs = 0;
	for (new i = 0; i < MAX_DOWNLOAD_PREFERENCES; i++) {
		g_rgiDownloadPrefs[i] = INVALID_DOWNLOAD_CATEGORY;
	}
	
	g_hCDownloadURL = FindConVar("sv_downloadurl");
	
	// Set redirect downloadurl.  If blank, the transmission of sv_downloadurl to the client is not changed.
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
	CreateNative("GetDownloadCategoryInfo", Native_GetDownloadCategoryInfo);
	CreateNative("GetLoadedDownloadCategories", Native_GetLoadedDownloadCategories);

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
	new Handle:hQuery = INVALID_HANDLE, iCategoryID;
	decl String:sQuery[MAX_SQL_QUERY_LENGTH];
	
	Format(sQuery, sizeof(sQuery), "SELECT categoryid FROM categories WHERE categoryname='%s'",
			category);
	hQuery = SQL_Query(g_hDatabase, sQuery);
	
	// Category does not exist; create it.
	if (SQL_GetRowCount(hQuery) == 0) {
		Format(sQuery, sizeof(sQuery),
				"INSERT OR REPLACE INTO categories (categoryid, categoryname, categorydesc, enabled) VALUES (NULL, '%s', '%s', '%b')",
				category, description, enabled);
		SQL_FastQuery(g_hDatabase, sQuery);
	}
	CloseHandle(hQuery);
	
	Format(sQuery, sizeof(sQuery), "SELECT categoryid FROM categories WHERE categoryname='%s'",
			category);
	hQuery = SQL_Query(g_hDatabase, sQuery);
	SQL_FetchRow(hQuery);
	iCategoryID = SQL_FetchInt(hQuery, 0);
	
	CloseHandle(hQuery);
	
	DownloadCategoryAdded(iCategoryID);
	
	return iCategoryID;
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
RegClientDownloadFile(categoryid, const String:filepath[]) {
	decl String:sQuery[MAX_SQL_QUERY_LENGTH];
	Format(sQuery, sizeof(sQuery),
			"INSERT OR REPLACE INTO files (categoryid, filepath) VALUES (%d, '%s')",
			categoryid, filepath);
	SQL_FastQuery(g_hDatabase, sQuery);
}

public Native_RegClientDownloadFile(Handle:hPlugin, nParams) {
	new categoryid = GetNativeCell(1);
	decl String:filepath[PLATFORM_MAX_PATH]; GetNativeString(2, filepath, sizeof(filepath));
	
	RegClientDownloadFile(categoryid, filepath);
}

/**
 * Stores the client's download preference.
 */
SetClientDownloadPreference(client, categoryid, bool:enabled) {
	decl String:sQuery[MAX_SQL_QUERY_LENGTH];
	new sid3 = GetSteamAccountID(client);
	
	if (ClientHasDownloadPreference(client, categoryid)) {
		// Update existing entry.
		Format(sQuery, sizeof(sQuery), "UPDATE downloadprefs SET enabled = %d WHERE sid3 = %d AND categoryid = %d",
				_:enabled, sid3, categoryid);
	} else {
		// Create new entry.
		Format(sQuery, sizeof(sQuery), "INSERT INTO downloadprefs (sid3, categoryid, enabled) VALUES (%d, %d, %d)",
				sid3, categoryid, _:enabled);
	}
	SQL_FastQuery(g_hDatabase, sQuery);
}

public Native_SetClientDownloadPreference(Handle:hPlugin, nParams) {
	new client = GetNativeCell(1), categoryid = GetNativeCell(2), bool:enabled = GetNativeCell(3);
	SetClientDownloadPreference(client, categoryid, enabled);
}

/**
 * Retrieves a client's download preference.  If non-existent, will return the default setting.
 * A client will keep their existing download preference until a map change or reconnect.
 */
bool:GetClientDownloadPreference(client, categoryid) {
	decl String:sQuery[MAX_SQL_QUERY_LENGTH];
	new bool:bEnabled;
	
	if (!ClientHasDownloadPreference(client, categoryid, bEnabled)) {
		Format(sQuery, sizeof(sQuery), "SELECT enabled FROM categories WHERE categoryid=%d",
				categoryid);
		bEnabled = bool:SQL_QuerySingleRowInt(g_hDatabase, sQuery);
	}
	
	return bEnabled;
}

public Native_GetClientDownloadPreference(Handle:hPlugin, nParams) {
	new client = GetNativeCell(1), categoryid = GetNativeCell(2);
	return GetClientDownloadPreference(client, categoryid);
}

/**
 * Checks whether or not the client has their own download preference set.
 */
bool:ClientHasDownloadPreference(client, categoryid, &any:result = 0) {
	new sid3 = GetSteamAccountID(client);
	decl String:sQuery[MAX_SQL_QUERY_LENGTH];
	new Handle:hQuery = INVALID_HANDLE;
	new bool:bHasRows;

	Format(sQuery, sizeof(sQuery), "SELECT enabled FROM downloadprefs WHERE sid3=%d AND categoryid=%d",
			sid3, categoryid);
	hQuery = SQL_Query(g_hDatabase, sQuery);
	
	bHasRows = (SQL_GetRowCount(hQuery) > 0);
	
	if (bHasRows) {
		SQL_FetchRow(hQuery);
		result = bool:SQL_FetchInt(hQuery, 0);
	}
	
	CloseHandle(hQuery);
	
	return bHasRows;
}

public Native_ClientHasDownloadPreference(Handle:hPlugin, nParams) {
	new client = GetNativeCell(1), categoryid = GetNativeCell(2), result = GetNativeCellRef(3);
	return ClientHasDownloadPreference(client, categoryid, result);
}

/**
 * Gets the description of the download category.
 */
bool:GetDownloadCategoryInfo(categoryid, String:title[], maxTitleLength, String:description[], maxDescLength) {
	decl String:sQuery[MAX_SQL_QUERY_LENGTH];
	new Handle:hQuery = INVALID_HANDLE;
	
	Format(sQuery, sizeof(sQuery), "SELECT categoryname, categorydesc FROM categories WHERE categoryid=%d",
			categoryid);
	hQuery = SQL_Query(g_hDatabase, sQuery);
	
	new bool:bHasRows = (SQL_GetRowCount(hQuery) > 0);
	
	if (bHasRows) {
		SQL_FetchRow(hQuery);
		SQL_FetchString(hQuery, 0, title, maxTitleLength);
		SQL_FetchString(hQuery, 1, description, maxDescLength);
	}
	
	CloseHandle(hQuery);
	return bHasRows;
}

public Native_GetDownloadCategoryInfo(Handle:hPlugin, nParams) {
	new categoryid = GetNativeCell(1), maxTitleLength = GetNativeCell(3), maxDescLength = GetNativeCell(5);
	new String:title[maxTitleLength], String:description[maxDescLength];
	
	new bool:bResult = GetDownloadCategoryInfo(categoryid, title, maxTitleLength, description, maxDescLength);
	
	SetNativeString(2, title, maxTitleLength);
	SetNativeString(3, description, maxDescLength);
	
	return bResult;
}

DownloadCategoryAdded(categoryid) {
	new bool:bFound = false;
	
	for (new i = 0; i < g_nDownloadPrefs; i++) {
		bFound |= (categoryid == g_rgiDownloadPrefs[i]);
	}
	
	if (!bFound && g_nDownloadPrefs < MAX_DOWNLOAD_PREFERENCES) {
		g_rgiDownloadPrefs[g_nDownloadPrefs++] = categoryid;
	}
}

public Native_GetLoadedDownloadCategories(Handle:hPlugin, nParams) {
	new size = GetNativeCell(2), start = GetNativeCell(3), nCategories;
	new categoryids[size];
	
	for (new i = start; i < g_nDownloadPrefs; i++) {
		if (g_rgiDownloadPrefs[i] != INVALID_DOWNLOAD_CATEGORY) {
			categoryids[nCategories++] = g_rgiDownloadPrefs[i];
		}
	}
	
	SetNativeArray(1, categoryids, size);
	
	return nCategories;
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
