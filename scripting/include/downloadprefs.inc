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
    MarkNativeAsOptional("RegClientDownloadFile");
    MarkNativeAsOptional("SetClientDownloadPreference");
    MarkNativeAsOptional("GetClientDownloadPreference");
    MarkNativeAsOptional("ClientHasDownloadPreference");
    MarkNativeAsOptional("GetDownloadCategoryInfo");
    MarkNativeAsOptional("GetLoadedDownloadCategories");
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
native _:RegClientDownloadCategory(const String:category[], const String:description[], bool:enabled = true);

/**
 * Registers a file to a category.
 * 
 * @param categoryid        The ID of the category to register.
 * @param filepath          The full path of the file to download.
 */
native RegClientDownloadFile(categoryid, const String:filepath[]);

/**
 * Stores the client's download preference.
 * 
 * @param client            The client to set preferences for.
 * @param categoryid        The category of files to set a download preference for.
 * @param download          Whether or not the client downloads this file.
 */
native SetClientDownloadPreference(client, categoryid, bool:enabled);

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
native bool:GetClientDownloadPreference(client, categoryid);

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
native bool:ClientHasDownloadPreference(client, categoryid, &any:result = 0);

/**
 * Gets the name and description of a download preference.
 *
 * @param categoryid        The category to get a name / description of.
 * @param title             Buffer to store category name.
 * @param maxTitleLength    Size of title buffer.
 * @param description       Buffer to store category description.
 * @param maxDescLength     Size of description buffer.
 *
 * @return                  Whether or not the category exists.
 */
native bool:GetDownloadCategoryInfo(categoryid, String:title[], maxTitleLength, String:description[], maxDescLength);

/**
 * Gets an array containing loaded categoryids.
 *
 * @return                  The number of categories loaded.
 */
native _:GetLoadedDownloadCategories(categoryids[], size, start = 0);