#!/bin/sh
### BEGIN INIT INFO
# Provides: ISPC MINOR FIXER
# Required-Start: $local_fs $network
# Required-Stop: $local_fs
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: ISPC MINOR FIXER
# Description: Fix installer_base.lib.php v3.2.8p2 from line 3179 to 3188 and change mysql root password
### END INIT INFO

ispc3="/tmp/ispconfig3_install/install"
if [ -d "$ispc3" ]; then 
	# installer fixer
	cd /tmp/ispconfig*/install/lib
	wget https://raw.githubusercontent.com/ahrasis/Multi-ISPConfig-Server-Script/main/replace.txt
	sed -i $'3179r replace.txt\n;3179,3188d' installer_base.lib.php
fi
ispc-ai="/tmp/ispconfig-ai/var/log"
if [ -d "$ispc-ai" ]; then 
	# change mysql root password
	SLOG=$(ls /tmp/ispconfig-ai/var/log/setup*)
	LINE=$(awk '/Your MySQL root password is/' $SLOG)
	GENPW=$($echo "$LINE" | awk '{print $NF}')
	user=root
	password=$GENPW # change to password given by ISPConfig AI accordingly
	database=mysql
	# change ChangeMePW to your preferred password
	mysql --user="$user" --password="$password" --database="$database" --execute="ALTER USER 'root'@'localhost' IDENTIFIED BY 'ChangeMePW';"
fi
