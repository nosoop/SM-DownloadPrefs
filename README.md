SM-DownloadPrefs
================
A SourceMod library allowing clients to pick and choose their downloads.

Provides a bunch of methods to store and retrieve preferences for groups of files that are expected to be downloaded across maps.
Combined with a PHP script to read preferences for clients by IP address and a rewrite rule in the HTTPD of choice, this allows a web server to prevent clients from downloading files that they do not want.
