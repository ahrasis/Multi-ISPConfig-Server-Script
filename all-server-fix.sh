#!/bin/bash

# temporary solution but will use find and replace proper command in the future
cd /tmp/ispconfig*/install/lib
rm installer_base.lib.php
wget https://git.ispconfig.org/ahrasis/ispconfig3/-/raw/fix2210271528/install/lib/installer_base.lib.php

# temporary solution but will use find and replace proper command in the future
user=root
password=PW-BY-ISPC-AI # change to password given by ISPConfig AI accordingly
database=mysql
# change  NEWPASSWORD to your  preferred password
mysql --user="$user" --password="$password" --database="$database" --execute="ALTER USER 'root'@'localhost' IDENTIFIED BY 'NEWPASSWORD';"

# you can continue with installing ISPConfig that you put on hold pending this fix
