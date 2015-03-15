SM-DownloadPrefs
================
A SourceMod library allowing clients to pick and choose their downloads.

Provides a bunch of methods to store and retrieve preferences for groups of files that are expected to be downloaded across maps.
Combined with a PHP script to read preferences for clients and a rewrite rule in the HTTPD of choice, this allows a web server to prevent clients from downloading files that they do not want.

How to Set Up
-------------
1.  Ensure you have PHP and an appropriate database driver installed on your web server.
2.  Copy contents from `./www` to a `$SOMEPLACE` on your webserver and copy `./configs`, `./data`, and `./scripting` to your SourceMod installation.
3.  Set the rewrite rules accordingly.
4.  Add a `downloadprefs` entry to `addons/sourcemod/configs/databases.cfg`.  Only the SQLite driver is supported at the moment.
5.  Copy the `$SOMEPLACE/dprefs.example.conf.php` file to `$SOMEPLACE/dprefs.conf.php` and change the values in the file where appropriate.  If you renamed `dprefs.php` to a different filename, just change the config file to match.
6.  Compile the source for and install the `downloadprefs.smx` plugin file.  Enable it and modify `cfg/sourcemod/plugin.downloadprefs.cfg` to set `sm_dprefs_downloadurl` to your redirecting URL.
7.  Add plugins that support the `downloadprefs` library.  All zero of them, publicly.
8.  Enjoy letting people choose their downloads.  (Well, it would be helpful if you also compiled and installed `downloadprefs_menu.smx`, provided you don't have a plugin to automatically handle it.)

Download Preferences Custom URL
-------------------------------
Treat `sm_dprefs_downloadurl` as you would `sv_downloadurl`, but with an additional token `$STEAMID` that is replaced with the player's account number.

Not necessary, but do provide a valid `sv_downloadurl` as a fallback.

Example Configuration
---------------------
**tl;dr** Redirect a virtual directory structure containing a SteamID3 (account ID) and a file path to a PHP script.

For this example, we'll assume the following:
  * `sm_dprefs_downloadurl` is set to `http://server.fastdl/dprefs/tf/$STEAMID`.
  * The game's base directory is `/path/to/game`.
  * The PHP script would be reachable via `http://server.fastdl/dprefs.php` on redirect.
  * The actual fastdownload files are located at `http://server.fastdl/tf` (subdirectories being `sound`, `maps`, &c.).
  * An SQLite database holds the download preferences.

### In SourceMod's databases.cfg
  * Add a new database as follows:
```
"downloadprefs"
{
	"driver"		"sqlite"
	"database"		"downloadprefs"
}
```

### In dprefs.conf.php:
  * Set `$downloadDir` to `http://server.fastdl/tf`.
  * Ensure the following lines are in the file so that the download filter is using SQLite:
```
$dbFile = dirname(__FILE__) . '/downloadprefs.sq3';
require_once(dirname(__FILE__) . '/dprefs_sq3.php');
$prefsFilter = new SQLiteDownloadFilter($dbFile);
```

### If using lighttpd:
  * Add this to `lighttpd.conf`: `url.rewrite-once += ( "^/dprefs/tf/(\d+)/(.*)" => "/dprefs.php?steamid=$1&file=$2" )`
  * Force reload the server configuration.
