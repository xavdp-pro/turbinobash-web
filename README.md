# turbinobash-web

**turbinobash-web** is a small commandline PLESK like

The purpose isn't a DOCKER like : Its a tool between raw server administration and automated appilcation space management

Comptatible with Debian 12 and older + Ubuntu 24.04 and older

## turbinobash 

**turbinobash** is a bash framewok i made to manage bash script and script completion

**turbinobash-web** is a combination of 4 modules
* module : to manage modules
* app : to manage applications
* mysql : to manage mysql databases things
* template : to manage templates used with app

The most used module by user admin is app

There is **5 scripts** in the scripts directory to isntall 4 ways of web use :
* nginx : pure nginx usage + php fpm + mariadb
* apache : pure apache usage + php fpm + mariadb
* hybrid : nginx proxying towards apache + php fpm + mariadb
* proxy : nginx only use for proxying
* noweb : space application only for CRON without WEB (no Apache and no NGINX)

[![PMA INSTALL](https://img.youtube.com/vi/ZAB2zNwUv_k/1.jpg)](https://www.youtube.com/watch?v=ZAB2zNwUv_k)
[![WORDPRESS INSTALL EXEMPLE](https://img.youtube.com/vi/CGkAHvZpaOk/1.jpg)](https://www.youtube.com/watch?v=CGkAHvZpaOk)
[![TB INSTALL](https://img.youtube.com/vi/JCZSkcO8b84/1.jpg)](https://www.youtube.com/watch?v=JCZSkcO8b84)
---



### Install
```bash
cd /var/lib

git clone https://github.com/xavierdp/turbinobash-web.git

cd turbinobash-web/scripts
```

On a **Proxmox VE / PBS** host without an enterprise subscription, if `apt update` returns `401` on `enterprise.proxmox.com`, run as root **before** `nginx.sh` / `apache.sh` / … :

```bash
bash fix-proxmox-apt.sh
apt update
```

The script comments out active `enterprise.proxmox.com` lines and adds `pve-no-subscription` and/or `pbs-no-subscription` on `download.proxmox.com` only when a matching enterprise repo was enabled (so a plain Debian CT is left unchanged).

To **start the Proxmox VE web UI (port 8006)** when PVE is already installed (`pveproxy` present), run as root on the node:

```bash
bash pve-webui-8006.sh
```

If the script exits with “pveproxy is not installed”, this machine does not have Proxmox VE (e.g. PBS-only host uses **8007** only). Full PVE install: [Install Proxmox VE on Debian](https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian).

```bash
# johndoe@domain.tld is the email to use with letsencrypt
# sub.mydomain.tld is the sub domain pluged with the container's IP

# Theses is configuring the defaults for later uses :

# NGINX
bash nginx.sh johndoe@domain.tld sub.mydomain.tld

# APACHE2
bash apache.sh johndoe@domain.tld sub.mydomain.tld

# NGINX proxying APACHE2
bash hybrid.sh johndoe@domain.tld sub.mydomain.tld

# Just NGINX proxying
bash proxy.sh johndoe@domain.tld sub.mydomain.tld

# Only system NOWEB for stand alone CRON for example
bash noweb.sh

# Once the script has finished, quit BASH and enter again in your SHELL : it enabling TURBINOBASH completion !!!

```



### Set your DNS entries in the domain zone

- Create an A recod with the domain sub.mydomain.tld pointing on the contanier IP
- Create an A recod with the wildxard domain *.sub.mydomain.tld pointing on the contanier IP


![image](https://github.com/xavierdp/turbinobash-web/assets/38561912/0678f6d5-b19c-406f-a229-cf4078583749)

### apt purge

If you start lauch nginx.sh and after apache.sh, the nginx things are purged

If you start lauch apache.sh and after nginx.sh, the apache things are purged

If you start lauch apache.sh or nginx.sh and after proxy.sh, the apache and mariadb things are purged

### Usage for NGINX, APACHE or PROXY
```bash
# You have to install the good script to use the default way like theses :

# create test-v1.sub.mydomain.tld with SSL 
tb app sudo/create test-v1 --certbot

# create sub.myotherdomain.tld with SSL
tb app sudo/create test-v1 --certbot --webdomain=sub.myotherdomain.tld

# create sub.myotherdomain.tld and www.sub.myotherdomain.tld with SSL
tb app sudo/create test-v1 --certbot --webdomain=sub.myotherdomain.tld --www

# create a proxy towards a destination
tb app sudo/create test-v1 https://127.0.0.1/ --certbot

# create a system application for CRON usage for example
tb app sudo/create test-v1 --certbot --webdomain=sub.myotherdomain.tld --www

# so, if you need an other way from the default one you can use
tb app sudo/way/xxxx/create ...

```

### Turbinobash auto complete !!!

```bash

# just type and tab tab twice
tb app ↹ ↹ 

sudo/backup              sudo/info                sudo/install/mariadb     sudo/way/apache/create   sudo/way/noweb/remove
sudo/bulldozer           sudo/install/base        sudo/install/php         sudo/way/apache/remove   sudo/way/proxy/create
sudo/change/php          sudo/install/composer    sudo/install/ssl         sudo/way/hybrid/create   sudo/way/proxy/remove
sudo/copy                sudo/install/ct-proxmox  sudo/install/web         sudo/way/hybrid/remove   test
sudo/create              sudo/install/files       sudo/install/wp-cli      sudo/way/init            
sudo/diskalert           sudo/install/mail        sudo/remove              sudo/way/noweb/create  

# just type and tab tab twice
tb app sudo/remove 

coopnum-v1  pma-v1      pma-v2      qrcode-v2   toto-v1     zest-v1


# just type and tab tab twice
tb app sudo/create test-v1 --

--certbot          --remove           --template=joomla  --template=pma     --webdomain=       --www 


### ALL COMANDS HAVE AUTO COMPLETE !!! ###

```

# Structure of an app

## Directory scructure
Alls apps are in /apps

```console
root@test0:/apps/test-v1# tree
.
|-- app
|   `-- webroot
|       `-- index.php
|-- etc
|   |-- mysql
|   |   `-- localhost
|   |       `-- passwd
|   |-- php
|   |   `-- version
|   `-- ssh
|       `-- passwd
|-- log
|-- sav
`-- tmp
    `-- sessions

11 directories, 4 files
```
## test-v1 every where

- The app name is **test-v1**
- The sytem user is **test-v1**
- The db name is **test-v1**
- The db user is **test-v1**


```php
// wordpress wp-config usage 
define( 'DB_NAME', $_SERVER["USER"]);
define( 'DB_USER', $_SERVER["USER"]);
define( 'DB_PASSWORD', trim(file_get_contents("/apps/$_SERVER[USER]/etc/mysql/localhost/passwd")));
define( 'DB_HOST', 'localhost' );
```

### So each app is transportable !!

you make a test-v2

```bash
# copy files app from test-v1 to test-v2
cd /apps/test-v2
cp /apps/test-v1/app . -rf
```

```bash
# copy database from test-v1 to test-v2
mysqldump test-v1 | mysql test-v2
```

```bash
# Imagine it's a Wordpress : you have to replace the domain into the database
wp search-replace 'test-v1.sub.domain.tld' 'test-v2.sub.domain.tld'
```
https://developer.wordpress.org/cli/commands/search-replace/

Pif paf hopla and the test-v2 is ready !!

#### Apply the good rights to the files and directory

```bash
tb app sudo/bulldozer test-v1
```
#### Change PHP version
```bash
tb app sudo/change/php test-v1 8.1

# for CLI
update-alternatives --set php /usr/bin/php8.1
```

#### Install php version
```bash
tb app sudo/install/php 8.2
```

#### Install wp-cli
```bash
tb app sudo/install/wp-cli
```

#### Install composer
```bash
tb app sudo/install/composer

# if you need an other version
composer self-update 1.9.1
```


#### Install last MARIADB version
```bash
tb app sudo/install/mariadb
```

By default, MariaDB 11.4 LTS is installed from official repositories. Use `--system` to install from system repositories instead.

#### MySQL/MariaDB CLI compatibility

The scripts automatically detect and use the correct CLI command:
- **New systems (Debian 12+)**: uses `mariadb` command (no deprecation warnings)
- **Old systems**: uses `mysql` command

No configuration needed - it just works on both old and new systems.




#### Remove an app
```bash
tb app sudo/remove test-v1
```

#### Remove an app without asking

```bash
tb app sudo/remove test-v1 --force
```

#### backup an app (manual mode or specific mode)

```bash
tb app sudo/backup test-v1 
```

```console
############## MANUAL test-v1 APP /var/sav1/test0/manual/test-v1/23-09-25-21H47/test-v1.tar.bz2
############## MANUAL test-v1 DB /var/sav1/test0/manual/test-v1/23-09-25-21H47/test-v1.sql.bz2
############## Done
```

#### backup an app only db

```bash
tb app sudo/backup test-v1 db
```

#### backup an app only file

```bash
tb app sudo/backup test-v1 app
```

#### Crontab to backup All (crontab mode or all mode)

```bash
# m h  dom mon dow   command
30 3 * * * /bin/tb app sudo/backup All
```

##### /etc, /root and all apps are backuped so all could be restored

```console
root@test0:/var/sav1/test0# tree -sh
.
|-- [4.0K]  auto
|   `-- [4.0K]  23-09-25-22H15
|       `-- [4.0K]  test-v1
|           |-- [ 532]  test-v1.sql.bz2
|           `-- [2.6K]  test-v1.tar.bz2
`-- [4.0K]  system
    `-- [4.0K]  23-09-25-22H15
        |-- [497K]  etc.tar.bz2
        `-- [6.5K]  root.tar.bz2
```

##### Convention: nosav directory

The `nosav` directory is **always excluded** from backups. Use it to store files you don't want to backup (large files, caches, temporary data, etc.).

```bash
# Example: exclude large uploads from backup
mkdir /apps/myapp-v1/app/webroot/uploads/nosav
mv /apps/myapp-v1/app/webroot/uploads/large-files/* /apps/myapp-v1/app/webroot/uploads/nosav/
```

##### /root backup: only essential files

The `/root` backup only includes essential files (not heavy caches like `.npm`, `.cache`, `.ollama`, etc.):
- `.ssh/` - SSH keys
- `.bash_history`, `.bashrc`, `.bash_profile`, `.profile` - Bash config
- `.my.cnf` - MySQL/MariaDB config
- `.vimrc`, `.gitconfig` - Editor/Git config
- `sav/` - Personal backup directory (if exists)

#### Crontab to update SSL certificates
nginx version
```bash
# m h  dom mon dow   command
30 4,20 * * * /usr/bin/certbot --nginx renew --quiet;/usr/sbin/service nginx restart
```

#### Crontab diskalert 

Send a email if a partition is more filled tha 85%

```bash
# m h  dom mon dow   command
*/5 * * * * /bin/tb app sudo/diskalert name@domain.tld
```

#### TODO
Explain how templates are working

```bash
tb app sudo/create pma-v1 --certbot --template=pma
```

Add a an install mode to use à container which remote a proxy one to 

Backup crontab

## Wordpress installation exemple 

#### App test-v1 Wordpress installation

```bash
# App creation
tb app sudo/create test-v1 --certbot

cd /apps/test-v1/app

# Wordpress download
wget https://wordpress.org/latest.zip
unzip latest.zip

rm webroot -rf

mv wordpress webroot

cd webroot

# Rights bulldoser
tb app sudo/bulldozer test-v1

# Conf file copy
cp wp-config-sample.php wp-config.php


nano wp-config.php

```

```php
// remove current database conenction code and replace by

define( 'DB_NAME', $_SERVER["USER"]);
define( 'DB_USER', $_SERVER["USER"]);
define( 'DB_PASSWORD', trim(file_get_contents("/apps/$_SERVER[USER]/etc/mysql/localhost/passwd")));
define( 'DB_HOST', 'localhost' );

define('FS_METHOD', 'direct');
```

Goto your test-v1 app url https://test-v1.sub.domain.tld/ and finish the install


#### Copy test-v1 to test-v2

```bash
# Install wp-cli
tb app sudo/install/wp-cli

# App creation
tb app sudo/create test-v2 --certbot

cd /apps/test-v2

# Copy files from test-v1 to test-v2
cp /apps/test-v1/app/ . -rf

tb app sudo/bulldozer test-v2

# Copy database  from test-v1 to test-v2
mysqldump test-v1|mysql test-v2

# Become test-v2
su test-v2

cd

cd app/webroot


# replace test-v1 to test-v2 in database
wp search-replace "test-v1" "test-v2"

# Replace whatever you need in database with this tool
```

#### TADA

Goto your test-v2 app url https://test-v2.sub.domain.tld/ and the copy is working

### Some can be mixed

```bash
# NGINX one can be used with
tb app sudo/create app-v1
tb app sudo/remoe  app-v1

# because the
tb app sudo/way/init nginx $email $hostname $php_default_version
# in each installed script fix the mode

### BUT EXISTS ###
tb app sudo/way/  ↹ ↹ (TAB TAB)

sudo/way/apache/remove  sudo/way/hybrid/remove  sudo/way/nginx/create   sudo/way/noweb/create   sudo/way/proxy/create
# show the all way possible and you can mix them when possible

# If you insall th NGINX one, you can use the PROXY WAY or the NOWEB way 
tb app sudo/way/proxy/create app-v1
tb app sudo/way/noweb/create app-v1

# if YOU installed the HYNRID one, you can use the PROXY WAY, the NGINX way, or the NOWEB way if you need
tb app sudo/way/nginx/create app-v1
tb app sudo/way/proxy/create app-v1
tb app sudo/way/noweb/create app-v1
...

```

### Node JS EXPRESS example
```bash
apt install npm

tb app sudo/way/noweb/create express-v1

cd /apps/express-v1/app

npm i express

# Edit main.js Hello World
nano main.js
```

```javascript
const express = require('express')
const app = express()
const port = 3000

app.get('/', (req, res) => {
  res.send('Hello World!')
})

app.listen(port, () => {
  console.log(`Example app listening on port ${port}`)
})
```

```bash
node main.js
# Example app listening on port 3000

tb app sudo/way/proxy/create express-v1 http://127.0.0.1:3000 --certbot

curl https://express-v1.sub.domain.tld
# Hello World!

# or better in root user
npm install pm2 -g

su express-v1

cd /apps/express-v1/app
pm2 start main

# ENJOY !!!
```

![image](https://github.com/xavierdp/turbinobash-web/assets/38561912/567acf81-a492-4521-a085-74286ac01569)
![image](https://github.com/xavierdp/turbinobash-web/assets/38561912/6cd6f740-db3a-4b95-8914-7503a02ace14)



















