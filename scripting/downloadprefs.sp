/**
 * Download Preferences
 * Author(s): nosoop
 * File:  downloadprefs.sp
 * Description:  Allows clients to select categories of files to download.
 * License:  MIT License
 */

#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION          "0.2.1"

public Plugin:myinfo = {
    name = "Download Preferences",
    author = "nosoop",
    description = "Client download preferences",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop/SM-DownloadPrefs"
}

#define DATABASE_NAME           "downloadprefs"

new Handle:g_hDatabase = INVALID_HANDLE;

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
        RegisterClientIP(client);
    }
}

/**
 * Associates a client's SteamID3 with their current IP address.
 * This must be called after the client is authorized.
 */
RegisterClientIP(client) {
    decl String:sIPAddr[20], String:sQuery[1024];
    
    new iSteamID3 = GetSteamAccountID(client);
    GetClientIP(client, sIPAddr, sizeof(sIPAddr));
    
    Format(sQuery, sizeof(sQuery),
            "INSERT OR REPLACE INTO clients (sid3, ipaddr, lastconnect) VALUES ( %d, '%s', %d )",
            iSteamID3, sIPAddr, GetTime());
    
    SQL_FastQuery(g_hDatabase, sQuery);
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
 * CREATE TABLE 'clients' ('sid3' INTEGER PRIMARY KEY NOT NULL, 'ipaddr' TEXT NOT NULL, 'lastconnect' INTEGER NOT NULL);
 * CREATE TABLE 'downloadprefs' ('sid3' INTEGER NOT NULL, 'categoryid' INTEGER NOT NULL, 'enabled' BOOLEAN NOT NULL);
 * CREATE TABLE 'files' ('categoryid' INTEGER, 'filepath' TEXT PRIMARY KEY NOT NULL);
 */
 
 /**
  * Flow to check if a download is allowed.
  * When a client is authorized: -> Update IP, SteamID3, lastconnect in table clients
  * When a client downloads a file: ->
  *   - Get SteamID3 from the associated IP address in table clients,   (redirect / 404 if not found) (if multiple clients on same IP within short period, take worst case?)
  *   - Get 'categoryid' by 'filepath' in table files (filepath obtained in query string),
  *   - Get 'enabled' by 'sid3' and 'category' in downloadprefs,
  *   - (If not found, get 'enabled' by 'categoryid' in table categories),
  *   - If enabled, allow the download, otherwise redirect / 404.
  */
