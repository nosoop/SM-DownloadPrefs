SM-DownloadPrefs
================
A SourceMod library allowing clients to pick and choose their downloads.

Provides a bunch of methods to store and retrieve preferences for groups of files that are expected to be downloaded across maps.
Combined with a PHP script to read preferences for clients by IP address and a rewrite rule in the HTTPD of choice, this allows a web server to prevent clients from downloading files that they do not want.

How to Set Up
-------------
1.  Copy contents from `./www/` to your fast download server's `/tf/` directory.
2.  [pending]

Example Rewrite Rules
---------------------

In lighttpd:

```
	url.rewrite-once += ( "^/tf-dprefs/(\d+)/(.*)" => "/tf/downloadprefs_sqlite.php?steamid=$1&file=$2" )
```