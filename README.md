# SM-DownloadPrefs
A SourceMod library allowing clients to pick and choose their downloads.

Provides a bunch of methods to store and retrieve preferences for groups of files that are expected to be downloaded across maps.
Combined with a PHP script to read preferences for clients and a rewrite rule in the HTTPD of choice, this allows a web server to prevent clients from downloading files that they do not want.

## How to Set Up
1.  Ensure you have PHP and an appropriate database driver installed on your web server.
2.  Copy contents from `./www` to a `$SOMEPLACE` on your webserver and copy `./configs`, `./data`, and `./scripting` to your SourceMod installation.
3.  Set the rewrite rules accordingly.
4.  Add a `downloadprefs` entry to `addons/sourcemod/configs/databases.cfg`.  Only the SQLite driver is supported at the moment.
5.  Copy the `$SOMEPLACE/dprefs.example.conf.php` file to `$SOMEPLACE/dprefs.conf.php` and change the values in the file where appropriate.  If you renamed `dprefs.php` to a different filename, just change the config file to match.
6.  Compile the source for and install the `downloadprefs.smx` plugin file.  Enable it and modify `cfg/sourcemod/plugin.downloadprefs.cfg` to set `sm_dprefs_downloadurl` to your redirecting URL.
7.  Add plugins that support the `downloadprefs` library.  All zero of them, publicly.
8.  Enjoy letting people choose their downloads.  (Well, it would be helpful if you also compiled and installed `downloadprefs_menu.smx`, provided you don't have a plugin to automatically handle it.)

Lost?  See an [example configuration](https://github.com/nosoop/SM-DownloadPrefs/wiki/Sample-Configuration).

### Download Preferences Custom URL
Treat `sm_dprefs_downloadurl` as you would `sv_downloadurl`, but with an additional token `$STEAMID` that is replaced with the player's account number.

Not necessary, but do provide a valid `sv_downloadurl` as a fallback.
