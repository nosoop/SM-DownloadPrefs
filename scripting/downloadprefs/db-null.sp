/**
 * Download Preferences Component Template.
 *
 * Allows the developer to provide a different database interface for Download Preferences to work with.
 * Change the import in downloadprefs.sp and recompile.
 */
#pragma semicolon 1
#include <sourcemod>

/**
 * Define constants and database handles and whatever else you need to define.
 */
new Handle:g_hDatabase = INVALID_HANDLE;

/**
 * Called when the natives are registered and the database needs to be initialized.
 */
PrepareDatabase() {
	g_hDatabase = GetDatabase();
}

/**
 * Reads the database configuration.
 */
Handle:GetDatabase() { return INVALID_HANDLE; }

/**
 * Provides raw access to update the database for the specified SteamID.
 */
RawSetDownloadPreference(steamid, categoryid, bool:enabled) {}

/**
 * Grants raw access to retrieve the download preference for the specified SteamID and category.
 */
bool:RawGetDownloadPreference(steamid, categoryid) { return false; }

/**
 * Checks if a SteamID has a preference set for a category.
 */
bool:RawHasDownloadPreference(steamid, categoryid, &any:result = 0) { return false; }

/**
 * Assigns a file to a category.
 */
RawAssignFileCategory(categoryid, const String:filepath[]) {}

/**
 * Creates or retrieves a category.
 * The category name is used as the identifier.
 *
 * @return A categoryid value identifying the category that was created or used.
 */
_:RawCreateCategory(const String:category[], const String:description[], bool:enabled = true) {}

/**
 * Gets the description of the download category.
 *
 * @return Whether or not the operation was successful.
 */
bool:RawGetCategoryInfo(categoryid, String:title[], maxTitleLength, String:description[], maxDescLength) { return false; }
