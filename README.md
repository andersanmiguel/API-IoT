# API-IoT
A lighweight API for your IoT projects

This projects is designed to save data from IoT sensors in a secureway.

It uses two databses, one relational (MySQL or MariaDB) and another No-Relational (MOngoDB).

Relational database is used to store data from users, it has an admin and a non-admin user built-in on he DDL.

Installation
------------

- Enable mysqli extension on your php.ini by removing semicolon for this line:

;extension=php_mysqli.dll  

extension=php_mysqli.dll

If you do not have mysqli extension your can install with this command:

For php7:

sudo apt-get install php7.0-mysqli

For php5:

sudo apt-get install php5-mysqli

For mac is already installed of latest versions.

- Install MongoDB driver:

For GNU/Linux:

sudo pecl install mongodb

For mac:

brew install php70-mongodb

You can get more insformation about how to install MongoDb Driver on these page:

http://php.net/manual/es/mongodb.installation.pecl.php

http://php.net/manual/es/mongodb.installation.homebrew.php

Then on your php.ini create a new entry at the end of the file and point the full path to the mongodb.so extension:

For linux just use:

extension=mongodb.so

For isntance, this is my current extension path on mac:

extension="/usr/local/php5-7.1.13-20180201-134129/lib/php/extensions/no-debug-non-zts-20160303/mongodb.so"

Database and web services credentials
------------

Username: admin / Password: admin1234
Username: api_user / Password: user_api1234

All password are hashed and salted.

You can also try the API with a Postman sample available on databse folder.

Configuration
-------------

Set your connection parameters for MySQL/MariaDB and Mongo on utils/config.php

ENJOY!

