<?php
	// Custom configuration file for downloadprefs.
	// The $DPREFS.php will search for a file named $DPREFS.conf.php, where $DPREFS is the redirection script.
	
	// Redirected download path, refered to when redirecting the client to an accepted file.
	// By default it will use http://server.domain/tf
	$downloadDir = "http://$_SERVER[HTTP_HOST]/tf";
	
	// Error pages.  If you want to redirect any failures to a page, add them here.
	// Of course most clients will probably never see this.
	$errorPages = [
		"opt-in-required" => NULL,
		"unspecified-steamid" => NULL,
		"unspecified-file" => NULL,
	];
	
	// Optionally add a secret that the query has to contain.
	// Setting it to NULL bypasses the check.
	$secret = NULL;
	
	// Read clientprefs settings from an sqlite database.
	$dbFile = dirname(__FILE__) . '/downloadprefs.sq3';
	require_once(dirname(__FILE__) . '/dprefs_sq3.php');
	$prefsFilter = new SQLiteDownloadFilter($dbFile);
?>
