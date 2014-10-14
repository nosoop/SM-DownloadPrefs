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
