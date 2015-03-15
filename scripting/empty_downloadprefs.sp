/**
 * Download Preferences Template
 */

#pragma semicolon 1
#include <sourcemod>
#include <downloadprefs>

// Holds a number to set the preferences for "Some Sounds"
new g_iDownloadPref;

public OnPluginStart() {
	// Create a download category "Some Sounds", describing "A couple of sounds.", and by default downloads are disabled.
	// This value will someday not be consistent across loads of the downloadprefs library.
	g_iDownloadPref = RegClientDownloadCategory("Some Sounds", "A couple of sounds.", false);
	
	// Register a few files to the "Some Sounds" category.
	// Existing files will be recategorized to the specified category.
	RegClientDownloadFile(g_iDownloadPref, "sound/dprefs_sample/fart.wav");
	RegClientDownloadFile(g_iDownloadPref, "sound/dprefs_sample/pootis.wav");
}

/**
 * Call this function to enable / disable the "Some Sounds" category for a client.
 * The next time the client requests the file, the download will be allowed.
 */
SetSomeSoundsPreference(client, bool:enabled) {
	SetClientDownloadPreference(client, g_iDownloadPref, enabled);
}
