#if defined _downloadprefs_included
  #endinput
#endif
#define _downloadprefs_included

public SharedPlugin:__pl_downloadprefs = {
    name = "downloadprefs",
    file = "downloadprefs.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public __pl_downloadprefs_SetNTVOptional() {
	MarkNativeAsOptional("RegClientDownloadCategory");
	MarkNativeAsOptional("UnregClientDownloadCategories");
	
	MarkNativeAsOptional("RegClientDownloadFile");
	MarkNativeAsOptional("SetClientDownloadPreference");
	MarkNativeAsOptional("GetClientDownloadPreference");
	MarkNativeAsOptional("ClientHasDownloadPreference");
	
	MarkNativeAsOptional("GetCategoryInfo");
	MarkNativeAsOptional("GetAccessibleCategories");
}

enum DownloadPrefsAccess {
	DownloadPrefsAccess_Public, // Read / write access is given to all plugins
	DownloadPrefsAccess_Protected, // Read access is given to all plugins, writable only by host plugin
	DownloadPrefsAccess_Private, // Only host plugin is allowed to read / write to this category
}

/**
 * Registers a group of files to download.
 * Store the category plus description into the database if nonexistent, 
 * returning an ID to the corresponding category.
 * 
 * @param category          The category name to register.
 * @param description       The description associated with the category.
 * @param enabled           The file group is downloaded by default; clients must choose to opt-out.
 * @param access            The access level for this category.
 * 
 * @return id               A plugin-granted identifier for the category.
 */
native _:RegClientDownloadCategory(const String:category[], const String:description[], bool:enabled = true, DownloadPrefsAccess:access = DownloadPrefsAccess_Public);

/**
 * Unregisters all previously loaded categories associated with this plugin.
 */
native UnregClientDownloadCategories();

/**
 * Registers a file to a category.
 * 
 * @param id                The ID of the category to register.
 * @param filepath          The full path of the file to download.
 */
native RegClientDownloadFile(id, const String:filepath[]);

/**
 * Stores the client's download preference.
 * 
 * @param client            The client to set preferences for.
 * @param id                The category of files to set a download preference for.
 * @param download          Whether or not the client downloads this file.
 */
native SetClientDownloadPreference(client, id, bool:enabled);

/**
 * Retrieves a client's download preference.
 * A client will keep their existing download preference until a map change or reconnect.
 * 
 * @param client            The client to get preferences for.
 * @param id                The category of files to get a download preference for.
 * 
 * @return                  Boolean determining if a client allows downloads from this category,
 *                          or the default allow value if the client has not set their own.
 */
native bool:GetClientDownloadPreference(client, id);

/**
 * Checks whether or not the client has their own download preference set for a category.
 * 
 * @param client            The client to check preferences for.
 * @param id                The category of files to check for download preferences.
 * @param value             A cell reference to store an existing preference value.
 * 
 * @return                  Boolean determining if a custom download preference is set.
 *                          (False if using the default preference set by the download category.)
 */
native bool:ClientHasDownloadPreference(client, id, &any:result = 0);

/**
 * Gets the name and description of a download preference.
 *
 * @param id                The category to get a name / description of.
 * @param title             Buffer to store category name.
 * @param maxTitleLength    Size of title buffer.
 * @param description       Buffer to store category description.
 * @param maxDescLength     Size of description buffer.
 *
 * @return                  Whether or not the category exists.
 */
native bool:GetCategoryInfo(id, String:title[], maxTitleLength, String:description[], maxDescLength);

/**
 * Gets an array containing loaded categoryids.
 * 
 * @param ids               An array to store a list of identifiers that this plugin can access.
 * @param size              The maximum size of the array
 * @param start             The index of the array to start with.
 * 
 * @return                  The number of categories loaded.
 */
native _:GetAccessibleCategories(ids[], size, start = 0);
