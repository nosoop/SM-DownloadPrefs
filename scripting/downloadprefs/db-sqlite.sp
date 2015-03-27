/**
 * Download Preferences Component for SQLite databases.
 */
#pragma semicolon 1
#include <sourcemod>

#define MAX_SQL_QUERY_LENGTH 512

// Database name and related handle
#define DATABASE_NAME "downloadprefs"
new Handle:g_hDatabase = INVALID_HANDLE;

PrepareDatabase() {
	g_hDatabase = GetDatabase();
}

/**
 * Reads the database configuration.
 */
Handle:GetDatabase() {	
	new Handle:hDatabase = INVALID_HANDLE;
	
	if (SQL_CheckConfig(DATABASE_NAME)) {
		decl String:sErrorBuffer[256];
		if ( (hDatabase = SQL_Connect(DATABASE_NAME, true, sErrorBuffer, sizeof(sErrorBuffer))) == INVALID_HANDLE ) {
			SetFailState("[downloadprefs-sqlite] Could not connect to database: %s", sErrorBuffer);
		} else {
			return hDatabase;
		}
	} else {
		SetFailState("[downloadprefs-sqlite] Could not find configuration %s to load database.", DATABASE_NAME);
	}
	return INVALID_HANDLE;
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

/**
 * Grants raw access to retrieve the download preference for the specified SteamID and category.
 */
bool:GetRawDownloadPreference(steamid, categoryid) {
	decl String:sQuery[MAX_SQL_QUERY_LENGTH];
	new bool:bPreferenceEnabled;
	
	if (!HasRawDownloadPreference(steamid, categoryid, bPreferenceEnabled)) {
		// Fallback to default preference
		Format(sQuery, sizeof(sQuery), "SELECT enabled FROM categories WHERE categoryid=%d",
				categoryid);
		bPreferenceEnabled = bool:SQL_QuerySingleRowInt(g_hDatabase, sQuery);
	}
	
	return bPreferenceEnabled;
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

RawAssignFileCategory(categoryid, const String:filepath[]) {
	decl String:sQuery[MAX_SQL_QUERY_LENGTH];
	Format(sQuery, sizeof(sQuery),
			"INSERT OR REPLACE INTO files (categoryid, filepath) VALUES (%d, '%s')",
			categoryid, filepath);
	SQL_FastQuery(g_hDatabase, sQuery);
}

_:RawCreateCategory(const String:category[], const String:description[], bool:enabled = true) {
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
	return categoryid;
}

/**
 * Gets the description of the download category.
 */
bool:RawGetCategoryInfo(categoryid, String:title[], maxTitleLength, String:description[], maxDescLength) {
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

/**
 * Helper function.  Runs a query, returning the first integer from the first row.
 */
_:SQL_QuerySingleRowInt(Handle:database, const String:query[]) {
	new result;
	new Handle:hQuery = SQL_Query(database, query);
	
	result = SQL_FetchInt(hQuery, 0);
	CloseHandle(hQuery);
	
	return result;
}
