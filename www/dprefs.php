<?php
	// Example rewritten call:
	// http://example.com/downloadprefs_sqlite.php?file=sound/ui/gamestartup10.mp3&steamid=46714374

	// Required parameters:
	//   - file: Path to file to check for download preferences
	//   - steamid: The player's SteamID
	
	// Default settings
	interface DownloadFilter { public function getFilePreference($steamid, $filepath); }
	class DefaultDownloadFilter implements DownloadFilter { public function getFilePreference($steamid, $filepath) { return true; } }
	
	$prefsFilter = new DefaultDownloadFilter();
	$downloadDir = "http://$_SERVER[HTTP_HOST]/tf";
	$errorPages = [ "opt-in-required" => NULL, "unspecified-steamid" => NULL, "unspecified-file" => NULL, ];
	$secret = NULL;
	
	// Any values that exist in downloadprefs_sqlite.conf.php will overwrite the preferences above.
	$configFile = dirname(__FILE__) . '/' . basename(__FILE__, '.php') . '.conf.php';
	if (file_exists($configFile)) {
		include_once($configFile);
	}
?>

<?php
	$file = html_entity_decode($_REQUEST['file']);
	
	// Perform extra optional check to ensure that the redirection is done internally
	if (!is_null($secret)) {
		$querySecret = $_REQUEST['secret'];
		if (is_null($querySecret) || strcmp($secret, $querySecret) <> 0) {
			header("HTTP/1.1 403 Forbidden");
			return;
		}
	}
	
	if (!empty($file)) {
		// Queries database for non-bzipped version; easier than adding a check to test to add nonexistent .bz2 extension.
		$filenobzip = str_replace(".bz2", "", $file);
		
		/**
		 * $category might not exist if the file is not registered -- allow download anyways.
		 * $enabled may not exist if the client has no preference set -- default to category.
		 */
		
		if (isset($_REQUEST['steamid'])) {
			$sid3 = filter_var($_REQUEST['steamid'], FILTER_VALIDATE_INT);
			
			if ($prefsFilter->getFilePreference($sid3, $filenobzip)) {
				header("HTTP/1.1 307 Temporary Redirect");
				header("Location: $downloadDir/$file" );
				return;
			} else {
				// This file is opt-in.
				header("HTTP/1.1 404 Not Found");
				
				$errorPage = $errorPages['opt-in-required'];
				if (!is_null($errorPage)) {
					header("Location: $errorPage");
				}
				return;
			}
		} else {
			// Client has not specified a SteamID and accessed PHP page directly -- block download.
			header("HTTP/1.1 401 Unauthorized");
			
			$errorPage = $errorPages['unspecified-steamid'];
			if (!is_null($errorPage)) {
				header("Location: $errorPage");
			}
			return;
		}
	} else {
		// Client did not pass a file.
		header("HTTP/1.1 404 Not Found");
		
		$errorPage = $errorPages['unspecified-file'];
		if (!is_null($errorPage)) {
			header("Location: $errorPage");
		}
		return;
	}
?>
