<?php
	// SQLite Client Preferences filter.
	class SQLiteDownloadFilter implements DownloadFilter {
		private $db;
		
		function __construct($dbPath) {
			$this->db = new SQLite3($dbPath);
		}
		
		// Allow download of file if the file is not registered, if the default is to allow, or if the client opts in.
		public function getFilePreference($steamid, $filepath) {
			$category = $this->db->querySingle('SELECT categoryid FROM files WHERE filepath="'.SQLite3::escapeString($filepath).'"');
			
			$enabled = $this->db->querySingle('SELECT enabled FROM downloadprefs WHERE sid3="'.$steamid.'" AND categoryid='.SQLite3::escapeString($category).'');
			if (is_null($enabled)) {
				$enabled = $this->db->querySingle('SELECT enabled FROM categories WHERE categoryid='.$category);
			}
			
			// If the file is not registered or client did not set a custom preference, then allow.
			return is_null($category) || is_null($enabled) || $enabled == 1;
		}
	}
?>
