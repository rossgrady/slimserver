# slimserver
Server for Logitech Squeezebox players. This server is also called Logitech Media Server

This fork makes changes necessary to support MySQL 5.7.x as the database backend.

Note that DBD::mysql no longer ships with slimserver, so you'll need to add it, either to your perl module path, or to /CPAN/DBD

(I haven't uploaded it here)

To use mysql as your backend instead of SQLite (IMHO, necessary if you have > 30,000 audio files), you'll need the following stanza in your server.prefs file:

    dbpassword: XXXXXXXXX
    dbsource: dbi:mysql:hostname=127.0.0.1;port=3306;database=slimserver #obviously modify this as needed
    dbtype: MySQL
    dbusername: slimserver

Note especially the 'dbtype' entry, which isn't present anymore in shipping versions of LMS. Some online documentation suggests that it's sufficient to change dbsource to include dbi:mysql, but in my experience, LMS will just overwrite that line if the dbtype entry isn't also present.
