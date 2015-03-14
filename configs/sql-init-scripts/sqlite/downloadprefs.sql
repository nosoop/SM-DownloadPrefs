CREATE TABLE 'categories' (
	'categoryid' INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	'categoryname' TEXT NOT NULL,
	'categorydesc' TEXT,
	'enabled' BOOLEAN NOT NULL
);

CREATE TABLE 'downloadprefs' (
	'sid3' INTEGER NOT NULL,
	'categoryid' INTEGER NOT NULL,
	'enabled' BOOLEAN NOT NULL
);

CREATE TABLE 'files' (
	'categoryid' INTEGER,
	'filepath' TEXT PRIMARY KEY NOT NULL
);