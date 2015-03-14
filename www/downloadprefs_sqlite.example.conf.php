<?php
	// Custom configuration file for downloadprefs.
	// The $DPREFS.php will search for a file named $DPREFS.conf.php, where $DPREFS is the redirection script.

	// Path to database file.
	$dbFile = dirname(__FILE__) . '/clientproxy.sq3';
	
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
?>
