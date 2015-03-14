<?php
	// Example redirected call:
	// http://example.com/downloadprefs_sqlite.php?file=sound/ui/gamestartup10.mp3&steamid=46714374

	$file = html_entity_decode($_REQUEST['file']);

	if (!empty($file)) {
		// Client IP when using the fastdl should normally match the IP given to the game server.
		$ip = $_SERVER['REMOTE_ADDR'];
		
		// Queries database for non-bzipped version; easier than adding a check to test to add nonexistent .bz2 extension.
		$filenobzip = str_replace(".bz2", "", $file);
		
		$db = new SQLite3('./clientproxy.sq3');
		
		/**
		 * $sid3 will not exist for an IP address that did not use the server -- deny download.
		 * $category might not exist if the file is not registered -- allow download anyways.
		 * $enabled may not exist if the client has no preference set -- default to category.
		 * 
		 * Priority test: $sid3 > $category > $enabled
		 */
		
		if (isset($_REQUEST['steamid'])) {
			$sid3 = filter_var($_REQUEST['steamid'], FILTER_VALIDATE_INT);
			
			$category = $db->querySingle('SELECT categoryid FROM files WHERE filepath="'.SQLite3::escapeString($filenobzip).'"');
			// TODO allow download if is_null($category)
			
			$enabled = $db->querySingle('SELECT enabled FROM downloadprefs WHERE sid3="'.$sid3.'" AND categoryid='.SQLite3::escapeString($category).'');
			if (is_null($enabled)) {
				$enabled = $db->querySingle('SELECT enabled FROM categories WHERE categoryid='.$category);
			}
			
			$db->close();
			
			// If the file is not registered or client did not set a custom preference, then allow.
			if (is_null($category) || is_null($enabled) || $enabled == 1) {
				header("HTTP/1.1 307 Temporary Redirect");
				header("Location: http://$_SERVER[HTTP_HOST]/tf/$file" );
				return;
			} else {
				header("HTTP/1.1 404 File Not Found");
			}
		} else {
			// Client is not allowed to download.
			header("HTTP/1.1 404 File Not Found");
			return;
		}
	} else {
		// Client did not pass a query -- assume they found sv_downloadurl, redirect to some explanation file?
		header("HTTP/1.1 307 Temporary Redirect");
	
		$file = "downloadprefs.html";
		header("Location: http://$_SERVER[HTTP_HOST]/tf/$file" );
		return;
	}
?>
