
export DEBIAN_FRONTEND=noninteractive

if [ -z "$1" ]; then
  php=8.3
else
  php=$1
fi



mkdir -p /conf
mkdir -p /apps

echo "noweb" >/conf/mode
echo $php >/conf/php

apt update -y
apt dist-upgrade -y
apt install -y bash-completion curl nano

bash ../modules/module/wrappers/install

tb app sudo/install/base
tb app sudo/install/mariadb
tb app sudo/install/php $php
tb app sudo/install/web --noweb
tb app sudo/install/files

tb app sudo/install/mail $hostname

echo "# quit shell and comeback to enable tb completion"

echo "# MARIADB"
echo "# /root/.my.cnf"
cat /root/.my.cnf
