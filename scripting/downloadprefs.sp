/**
 * Download Preferences
 * Author(s): nosoop
 * File:  downloadprefs.sp
 * Description:  Allows clients to select categories of files to download.
 * License:  MIT License
 */

#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION          "0.1.0"

public Plugin:myinfo = {
    name = "Download Preferences",
    author = "nosoop",
    description = "Client download preferences",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop/SM-DownloadPrefs"
}

new Handle:g_hDatabase = INVALID_HANDLE;

public OnPluginStart() {
    // TODO get database handle
    g_hDatabase = INVALID_HANDLE;
}

/**
 * Stores the SteamID (to keep track of the client) plus the IP address to track the browser.
 * Also stores the current time in the event a database pruning is desirable.
 */
public OnClientAuthorized(client, const String:auth[]) {
    if (!IsFakeClient(client)) {
        decl String:sIPAddr[20];
        
        new iSteamID3 = GetSteamAccountID(client);
        GetClientIP(client, sIPAddr, sizeof(sIPAddr));
        
        // TODO Perform fast query to store the IP address.
    }
}

/**
 * Registers a group of files to download.
 * Store the category plus description into the database if nonexistent, 
 * returning an ID to the corresponding category.
 * 
 * @param category          The category name to register.
 * @param description       The description associated with the category.
 * @param default           The file group is downloaded by default; clients must choose to opt-out.
 * 
 * @return categoryid       The ID of the category.
 */
// _:RegClientDownloadCategory(const String:category[], const String:description[], bool:default = true);

/**
 * Registers a file to a category.
 * 
 * @param categoryid        The ID of the category to register.
 * @param filepath          The full path of the file to download.
 */
// RegClientDownloadFile(id, const String:filepath[]);

/**
 * Stores the client's download preference.
 * 
 * @param client            The client to set preferences for.
 * @param categoryid        The category of files to set a download preference for.
 * @param download          Whether or not the client downloads this file.
 */
// SetClientDownloadPreference(client, categoryid, bool:download);

/**
 * Retrieves a client's download preference.
 * A client will keep their existing download preference until a map change or reconnect.
 * 
 * @param client            The client to get preferences for.
 * @param categoryid        The category of files to get a download preference for.
 * 
 * @return                  Boolean determining if a client allows downloads from this category,
 *                          or the default allow value if the client has not set their own.
 */
// bool:GetClientDownloadPreference(client, categoryid);

/**
 * Tables to create:
 *
 * CREATE TABLE 'categories' ('categoryid' INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, 'categoryname' TEXT NOT NULL, 'categorydesc' INTEGER, 'enabled' BOOLEAN NOT NULL);
 * CREATE TABLE 'clients' ('sid3' INTEGER PRIMARY KEY NOT NULL, 'ipaddr' TEXT NOT NULL, 'lastconnect' INTEGER NOT NULL);
 * CREATE TABLE 'downloadprefs' ('sid3' INTEGER NOT NULL, 'categoryid' INTEGER NOT NULL, 'enabled' BOOLEAN NOT NULL);
 * CREATE TABLE 'files' ('categoryid' INTEGER, 'filepath' TEXT PRIMARY KEY NOT NULL);
 */
 
 /**
  * Flow to check if a download is allowed.
  * When a client is authorized: -> Update IP, SteamID3, lastconnect in table clients
  * When a client downloads a file: ->
  *   - Get SteamID3 from the associated IP address in table clients,   (redirect / 404 if not found)
  *   - Get 'categoryid' by 'filepath' in table files (filepath obtained in query string),
  *   - Get 'enabled' by 'sid3' and 'category' in downloadprefs,
  *   - (If not found, get 'enabled' by 'categoryid' in table categories),
  *   - If enabled, allow the download, otherwise redirect / 404.
  */