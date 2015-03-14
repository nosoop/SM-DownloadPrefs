SM-DownloadPrefs
================
A SourceMod library allowing clients to pick and choose their downloads.

Provides a bunch of methods to store and retrieve preferences for groups of files that are expected to be downloaded across maps.
Combined with a PHP script to read preferences for clients and a rewrite rule in the HTTPD of choice, this allows a web server to prevent clients from downloading files that they do not want.

How to Set Up
-------------
1.  Ensure you have PHP and an appropriate database driver installed on your web server.
2.  Copy contents from `./www/` to a `$SOMEPLACE` on your fast download server.
3.  Set the rewrite rules accordingly.
4.  Add a `downloadprefs` entry to `addons/sourcemod/configs/databases.cfg`.  Only the SQLite driver is supported at the moment.
5.  Copy the `$SOMEPLACE/downloadprefs_sqlite.example.conf.php` file to `$SOMEPLACE/downloadprefs_sqlite.conf.php` and change the values accordingly.  If you renamed `downloadprefs_sqlite.php` to a different filename, just change the config file to match.
6.  Install the `downloadprefs.smx` plugin file.  Enable it and modify `cfg/sourcemod/plugin.downloadprefs.cfg` to set `sm_dprefs_downloadurl` to your redirecting URL.
7.  Add plugins that support the `downloadprefs` library.  All zero of them, publicly.
8.  Enjoy letting people choose their downloads.

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
  * Set `$dbFile` to `path/to/game/addons/sourcemod/data/sqlite/downloadprefs.sq3`.

### If using lighttpd:
  * Add this to `lighttpd.conf`: `url.rewrite-once += ( "^/dprefs/tf/(\d+)/(.*)" => "/dprefs.php?steamid=$1&file=$2" )`
  * Force reload the server configuration.
