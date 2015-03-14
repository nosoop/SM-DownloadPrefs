/**
 * Download Preferences
 * Author(s): nosoop
 * File:  downloadprefs.sp
 * Description:  Allows clients to select categories of files to download.
 * License:  MIT License
 */

#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION          "0.3.1"

public Plugin:myinfo = {
    name = "Download Preferences",
    author = "nosoop",
    description = "Client download preferences",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop/SM-DownloadPrefs"
}

#define DATABASE_NAME           "downloadprefs" // Database name in config

new Handle:g_hDatabase = INVALID_HANDLE;

new Handle:g_hCDownloadURL = INVALID_HANDLE; // Handle to sv_downloadurl

new Handle:g_hCDPrefURL = INVALID_HANDLE;

public OnPluginStart() {
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

    g_hDatabase = GetDatabase();
    
    return APLRes_Success;
}

/**
 * Stores the SteamID (to keep track of the client) plus the IP address to track the browser.
 * Also stores the current time in the event a database pruning is desirable.
 */
public OnClientAuthorized(client, const String:auth[]) {
    if (!IsFakeClient(client)) {
        SendCustomDownloadDirectory(client);
    }
}

SendCustomDownloadDirectory(client) {
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
 * Registers a group of files to download.
 * Store the category plus description into the database if nonexistent, 
 * returning an ID to the corresponding category.
 * 
 * @param category          The category name to register.
 * @param description       The description associated with the category.
 * @param enabled           The file group is downloaded by default; clients must choose to opt-out.
 * 
 * @return categoryid       The ID of the category.
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
 * 
 * @param categoryid        The ID of the category to register.
 * @param filepath          The full path of the file to download.
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
 * 
 * @param client            The client to set preferences for.
 * @param categoryid        The category of files to set a download preference for.
 * @param download          Whether or not the client downloads this file.
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
 * 
 * @param client            The client to get preferences for.
 * @param categoryid        The category of files to get a download preference for.
 * 
 * @return                  Boolean determining if a client allows downloads from this category,
 *                          or the default allow value if the client has not set their own.
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
 * 
 * @param client            The client to check preferences for.
 * @param categoryid        The category of files to check for download preferences.
 * @param value             A cell reference to store an existing preference value.
 * 
 * @return                  Boolean determining if a custom download preference is set.
 *                          (False if using the default preference set by the download category.)
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
 * Tables to create:
 *
 * CREATE TABLE 'categories' ('categoryid' INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, 'categoryname' TEXT NOT NULL, 'categorydesc' TEXT, 'enabled' BOOLEAN NOT NULL);
 * CREATE TABLE 'downloadprefs' ('sid3' INTEGER NOT NULL, 'categoryid' INTEGER NOT NULL, 'enabled' BOOLEAN NOT NULL);
 * CREATE TABLE 'files' ('categoryid' INTEGER, 'filepath' TEXT PRIMARY KEY NOT NULL);
 */
 
 /**
  * Flow to check if a download is allowed.
  * When a client is authorized: -> Send custom virtual fastdl directory data
  * When a client downloads a file: ->
  *   - Get SteamID3 from query string
  *   - Get 'categoryid' by 'filepath' in table files (filepath obtained in query string),
  *   - Get 'enabled' by 'sid3' and 'category' in downloadprefs,
  *   - (If not found, get 'enabled' by 'categoryid' in table categories),
  *   - If enabled, allow the download, otherwise redirect / 404.
  */
