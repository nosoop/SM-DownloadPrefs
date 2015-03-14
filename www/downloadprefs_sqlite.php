<?php
	// Example rewritten call:
	// http://example.com/downloadprefs_sqlite.php?file=sound/ui/gamestartup10.mp3&steamid=46714374

	// Required parameters:
	//   - file: Path to file to check for download preferences
	//   - steamid: The player's SteamID
	
	// Default settings
	$dbFile = dirname(__FILE__) . '/downloadprefs.sq3';
	$downloadDir = "http://$_SERVER[HTTP_HOST]/tf";
	$errorPages = [ "opt-in-required" => NULL, "unspecified-steamid" => NULL, "unspecified-file" => NULL, ];
	
	// Any values that exist in downloadprefs_sqlite.conf.php will overwrite the preferences above.
	$configFile = dirname(__FILE__) . '/' . basename(__FILE__, '.php') . '.conf.php';
	if (file_exists($configFile)) {
		include_once($configFile);
	}
?>

<?php
	$file = html_entity_decode($_REQUEST['file']);
	
	if (!empty($file)) {
		// Queries database for non-bzipped version; easier than adding a check to test to add nonexistent .bz2 extension.
		$filenobzip = str_replace(".bz2", "", $file);
		
		$db = new SQLite3($dbFile);
		
		/**
		 * $category might not exist if the file is not registered -- allow download anyways.
		 * $enabled may not exist if the client has no preference set -- default to category.
		 */
		
		if (isset($_REQUEST['steamid'])) {
			$sid3 = filter_var($_REQUEST['steamid'], FILTER_VALIDATE_INT);
			
			$category = $db->querySingle('SELECT categoryid FROM files WHERE filepath="'.SQLite3::escapeString($filenobzip).'"');
			
			$enabled = $db->querySingle('SELECT enabled FROM downloadprefs WHERE sid3="'.$sid3.'" AND categoryid='.SQLite3::escapeString($category).'');
			if (is_null($enabled)) {
				$enabled = $db->querySingle('SELECT enabled FROM categories WHERE categoryid='.$category);
			}
			
			$db->close();
			
			// If the file is not registered or client did not set a custom preference, then allow.
			if (is_null($category) || is_null($enabled) || $enabled == 1) {
				header("HTTP/1.1 307 Temporary Redirect");
				header("Location: $downloadDir/$file" );
				return;
			} else {
				// This file is opt-in.
				header("HTTP/1.1 403 Forbidden");
				
				$errorPage = $errorPages['opt-in-required'];
				if (!is_null($errorPage)) {
					header("Location: $errorPage");
				}
				return;
			}
		} else {
			// Client has not specified a SteamID and accessed PHP page directly -- block download.
			header("HTTP/1.1 403 Forbidden");
			
			$errorPage = $errorPages['unspecified-steamid'];
			if (!is_null($errorPage)) {
				header("Location: $errorPage");
			}
			return;
		}
	} else {
		// Client did not pass a file.
		header("HTTP/1.1 403 Forbidden");
		
		$errorPage = $errorPages['unspecified-file'];
		if (!is_null($errorPage)) {
			header("Location: $errorPage");
		}
		return;
	}
?>
