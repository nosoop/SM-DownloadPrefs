/**
 * Download Preferences
 * Author(s): nosoop
 * File:  downloadprefs.sp
 * Description:	 Allows clients to select categories of files to download.
 * License:	 MIT License
 */

#pragma semicolon 1
#include <sourcemod>

#define PLUGIN_VERSION			"0.5.0"

public Plugin:myinfo = {
	name = "Download Preferences",
	author = "nosoop",
	description = "Client download preferences",
	version = PLUGIN_VERSION,
	url = "http://github.com/nosoop/SM-DownloadPrefs"
}

#define MAX_DOWNLOAD_PREFERENCES 64
new g_rgiDownloadPrefs[MAX_DOWNLOAD_PREFERENCES],
	g_nDownloadPrefs;

#define DATABASE_NAME			"downloadprefs" // Database name in config
new Handle:g_hDatabase = INVALID_HANDLE;

new Handle:g_hCDownloadURL = INVALID_HANDLE, // sv_downloadurl
	Handle:g_hCDPrefURL = INVALID_HANDLE; // sm_dprefs_downloadurl

functag OnDownloadCategoryAdded public(categoryid);
new Handle:g_hFCategoryAdded = INVALID_HANDLE;

public OnPluginStart() {
	CreateConVar("sm_dprefs_version", PLUGIN_VERSION, _, FCVAR_PLUGIN | FCVAR_NOTIFY);
	
	// Called when a category is added.
	g_hFCategoryAdded = CreateForward(ET_Ignore, Param_Cell, Param_String);
	
	g_nDownloadPrefs = 0;
	for (new i = 0; i < MAX_DOWNLOAD_PREFERENCES; i++) {
		g_rgiDownloadPrefs[i] = -1;
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
	CreateNative("HookDownloadCategoryAdd", Native_HookDownloadCategoryAdd);

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
	
	// downloadurl has no trailing slash
	new String:sClientDownloadURL[256];
	GetConVarString(g_hCDPrefURL, sClientDownloadURL, sizeof(sClientDownloadURL));
	
	if (strlen(sClientDownloadURL) > 0) {
		new String:sSteamID3[32];
		IntToString(iSteamID3, sSteamID3, sizeof(sSteamID3));
			
		// Replace $STEAMID with client's SteamID3 and transmit to client
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
		new String:sDefaultDownloadURL[256];
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
	decl String:sQuery[1024];
	
	Format(sQuery, sizeof(sQuery),
			"SELECT categoryid FROM categories WHERE categoryname='%s'",
			category);
	hQuery = SQL_Query(g_hDatabase, sQuery);
	
	if (SQL_GetRowCount(hQuery) == 0) {
		Format(sQuery, sizeof(sQuery),
				"INSERT OR REPLACE INTO categories (categoryid, categoryname, categorydesc, enabled) VALUES (NULL, '%s', '%s', '%b')",
				category, description, enabled);
		SQL_FastQuery(g_hDatabase, sQuery);
	}
	CloseHandle(hQuery);
	
	Format(sQuery, sizeof(sQuery),
			"SELECT categoryid FROM categories WHERE categoryname='%s'",
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
	decl String:sQuery[1024];
	Format(sQuery, sizeof(sQuery),
			"INSERT OR REPLACE INTO files (categoryid, filepath) VALUES (%d, '%s')",
			categoryid, filepath);
	SQL_FastQuery(g_hDatabase, sQuery);
}

public Native_RegClientDownloadFile(Handle:hPlugin, nParams) {
	new categoryid = GetNativeCell(1);
	
	decl String:filepath[512];
	GetNativeString(2, filepath, sizeof(filepath));
	
	RegClientDownloadFile(categoryid, filepath);
}

/**
 * Stores the client's download preference.
 */
SetClientDownloadPreference(client, categoryid, bool:enabled) {
	decl String:sQuery[1024];

	new sid3 = GetSteamAccountID(client);
	
	if (ClientHasDownloadPreference(client, categoryid)) {
		// Update existing entry.
		Format(sQuery, sizeof(sQuery),
				"UPDATE downloadprefs SET enabled = %d WHERE sid3 = %d AND categoryid = %d",
				_:enabled, sid3, categoryid);
	} else {
		// Create new entry.
		Format(sQuery, sizeof(sQuery),
				"INSERT INTO downloadprefs (sid3, categoryid, enabled) VALUES (%d, %d, %d)",
				sid3, categoryid, _:enabled);
	}
	SQL_FastQuery(g_hDatabase, sQuery);
}

public Native_SetClientDownloadPreference(Handle:hPlugin, nParams) {
	new client = GetNativeCell(1),
		categoryid = GetNativeCell(2),
		bool:enabled = GetNativeCell(3);

	SetClientDownloadPreference(client, categoryid, enabled);
}

/**
 * Retrieves a client's download preference.  If non-existent, will return the default setting.
 * A client will keep their existing download preference until a map change or reconnect.
 */
bool:GetClientDownloadPreference(client, categoryid) {
	decl String:sQuery[1024];
	new bool:bEnabled;
	
	if (!ClientHasDownloadPreference(client, categoryid, bEnabled)) {
		Format(sQuery, sizeof(sQuery),
				"SELECT enabled FROM categories WHERE categoryid=%d",
				categoryid);
		bEnabled = bool:SQL_QuerySingleRowInt(g_hDatabase, sQuery);
	}
	
	return bEnabled;
}

public Native_GetClientDownloadPreference(Handle:hPlugin, nParams) {
	new client = GetNativeCell(1),
		categoryid = GetNativeCell(2);

	return GetClientDownloadPreference(client, categoryid);
}

/**
 * Checks whether or not the client has their own download preference set.
 */
bool:ClientHasDownloadPreference(client, categoryid, &any:result = 0) {
	new sid3 = GetSteamAccountID(client);
	decl String:sQuery[1024];
	new Handle:hQuery = INVALID_HANDLE;
	new bool:bHasRows;

	Format(sQuery, sizeof(sQuery),
			"SELECT enabled FROM downloadprefs WHERE sid3=%d AND categoryid=%d",
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
	new client = GetNativeCell(1),
		categoryid = GetNativeCell(2),
		result = GetNativeCellRef(3);

	return ClientHasDownloadPreference(client, categoryid, result);
}

/**
 * Gets the description of the download category.
 */
bool:GetDownloadCategoryInfo(categoryid, String:title[], maxTitleLength, String:description[], maxDescLength) {
	decl String:sQuery[1024];
	new Handle:hQuery = INVALID_HANDLE;
	
	Format(sQuery, sizeof(sQuery),
			"SELECT categoryname, categorydesc FROM categories WHERE categoryid=%d",
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
	new categoryid = GetNativeCell(1),
		maxTitleLength = GetNativeCell(3),
		maxDescLength = GetNativeCell(5);
	
	new String:title[maxTitleLength],
		String:description[maxDescLength];
	
	new bool:bResult = GetDownloadCategoryInfo(categoryid, title, maxTitleLength, description, maxDescLength);
	
	SetNativeString(2, title, maxTitleLength);
	SetNativeString(3, description, maxDescLength);
	
	return bResult;
}

/**
 * Private forward that is called when a download category is added.
 */
public Native_HookDownloadCategoryAdd(Handle:hPlugin, nParams) {
	new OnDownloadCategoryAdded:listeningFunction = GetNativeCell(1);
	AddToForward(g_hFCategoryAdded, hPlugin, listeningFunction);
	
	// Call for already existing categories
	for (new i = 0; i < g_nDownloadPrefs; i++) {
		new category = g_rgiDownloadPrefs[i];
		if (category > -1) {
			Call_StartFunction(hPlugin, listeningFunction);
			Call_PushCell(category);
			Call_Finish();
		}
	}
}

DownloadCategoryAdded(categoryid) {
	new bool:bFound = false;
	
	for (new i = 0; i < g_nDownloadPrefs; i++) {
		bFound |= (categoryid == g_rgiDownloadPrefs[i]);
	}
	
	if (!bFound && g_nDownloadPrefs < MAX_DOWNLOAD_PREFERENCES) {
		g_rgiDownloadPrefs[g_nDownloadPrefs++] = categoryid;
	}

	Call_StartForward(g_hFCategoryAdded);
	Call_PushCell(categoryid);
	Call_Finish();
}

/**
 * Runs a query, returning the selected integer from the first row.
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
