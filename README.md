# turbinobash-web

## At a glance

**turbinobash-web** is a **Plesk-like hosting stack in Bash** for Debian/Ubuntu: many isolated web apps on one server, managed from the shell with tab completion — not Docker, not a control panel in the browser.

| You get | You manage yourself |
|--------|---------------------|
| Per-app Linux user, webroot, MariaDB DB, vhost, PHP-FPM pool, optional SSL | Firewall, `iptables`, `ufw`, routing, hardware, OS hardening |

**One command shape for everything:**

```text
tb <module> <script-path> [arguments…] [--options]
```

Example: `tb app sudo/create mysite-v1 --certbot` creates app **mysite-v1**, user **mysite-v1**, database **mysite-v1**, nginx/apache vhost, and can request a Let’s Encrypt certificate.

**One name everywhere:** app `test-v1` → system user `test-v1` → MariaDB user and database `test-v1` → files under `/apps/test-v1/`.

**Typical first run (as root):**

1. Clone to `/var/lib/turbinobash-web`, run **one** bootstrap under `scripts/` (e.g. `bash nginx.sh you@domain.tld apps.domain.tld`).
2. Open a **new shell** so `/bin/tb` completion works.
3. Create apps with `tb app sudo/create …` — see sections below for WordPress, proxy, backups.

**Where to read next:** stay on this page for install and daily ops. For how `tb` runs scripts, resolves paths, and completes arguments (`#C#` lines), see **[docs/FRAMEWORK.md](docs/FRAMEWORK.md)**.

Compatible with **Debian 12+** (including Trixie) and **Ubuntu 24.04+**. First versions of the framework date from **2009**; this repository is the current **turbinobash-web** tree.

---

## turbinobash framework

**turbinobash** (`tb`) is the core: modular Bash scripts under `modules/`, `sudo/` helpers (auto-elevate to root), and **dynamic tab completion** on modules, script paths, app names, and flags.

Install once from any `scripts/*.sh` bootstrap — it calls `modules/module/wrappers/install` and creates `/bin/tb` plus bash completion.

**turbinobash-web** ships four modules:

| Module | Role |
|--------|------|
| `module` | Core: `tb` wrapper, completion, shared functions |
| `app` | Applications: vhosts, PHP-FPM pools, SSL, backups (main module for admins) |
| `mysql` | Thin CLI around MariaDB/MySQL admin (users, databases, grants, dumps) |
| `template` | App templates (phpMyAdmin, Joomla, …) used with `tb app sudo/create` |

### Hosting profiles (`scripts/`)

Pick **one** bootstrap script — it installs the stack and sets defaults under `/conf/`:

| Script | Stack |
|--------|--------|
| `nginx.sh` | Nginx + PHP-FPM + MariaDB |
| `apache.sh` | Apache + PHP-FPM + MariaDB |
| `hybrid.sh` | Nginx (front) → Apache + PHP-FPM + MariaDB |
| `proxy.sh` | Nginx reverse proxy only |
| `noweb.sh` | App spaces without a web server (cron, Node, etc.) |

[![PMA INSTALL](https://img.youtube.com/vi/ZAB2zNwUv_k/1.jpg)](https://www.youtube.com/watch?v=ZAB2zNwUv_k)
[![WORDPRESS INSTALL EXAMPLE](https://img.youtube.com/vi/CGkAHvZpaOk/1.jpg)](https://www.youtube.com/watch?v=CGkAHvZpaOk)
[![TB INSTALL](https://img.youtube.com/vi/JCZSkcO8b84/1.jpg)](https://www.youtube.com/watch?v=JCZSkcO8b84)

---

## Install

```bash
cd /var/lib
git clone https://github.com/xavdp-pro/turbinobash-web.git
cd turbinobash-web/scripts
```

Run **one** profile as root (`johndoe@domain.tld` = Let's Encrypt contact, `sub.mydomain.tld` = default app base domain):

```bash
bash nginx.sh johndoe@domain.tld sub.mydomain.tld
# bash apache.sh johndoe@domain.tld sub.mydomain.tld
# bash hybrid.sh johndoe@domain.tld sub.mydomain.tld
# bash proxy.sh johndoe@domain.tld sub.mydomain.tld
# bash noweb.sh
```

After install, defaults are stored in:

| File | Meaning |
|------|---------|
| `/conf/mode` | Active profile: `nginx`, `apache`, `hybrid`, `proxy`, or `noweb` |
| `/conf/email` | Let's Encrypt registration email |
| `/conf/webdomain` | Default FQDN suffix for new apps (`app-v1` → `app-v1.sub.mydomain.tld`) |
| `/conf/php` | Default PHP version for new apps |

`tb app sudo/create` reads `/conf/mode` and delegates to `tb app sudo/way/<mode>/create`. Override with explicit `tb app sudo/way/nginx/create`, etc.

### DNS (for HTTPS and wildcards)

- `A` record: `sub.mydomain.tld` → server IP
- `A` record: `*.sub.mydomain.tld` → server IP

![image](https://github.com/xavdp-pro/turbinobash-web/assets/38561912/0678f6d5-b19c-406f-a229-cf4078583749)

### Switching bootstrap scripts (`apt purge`)

Re-running a different `scripts/*.sh` **replaces** the previous web stack:

- `nginx.sh` then `apache.sh` → nginx stack removed
- `apache.sh` then `nginx.sh` → apache stack removed
- `nginx.sh` or `apache.sh` then `proxy.sh` → apache and MariaDB removed

### Framework paths (per app `myapp-v1`)

| Path | Purpose |
|------|---------|
| `/apps/myapp-v1/` | App home (system user home directory) |
| `/apps/myapp-v1/app/webroot/` | Document root |
| `/apps/myapp-v1/etc/mysql/localhost/passwd` | DB password for this app |
| `/etc/nginx/sites-enabled/10-myapp-v1.conf` | Nginx vhost (nginx/hybrid/proxy modes) |
| `/etc/apache2/sites-enabled/10-myapp-v1.conf` | Apache vhost (apache/hybrid modes) |
| `/etc/php/<ver>/fpm/pool.d/10-myapp-v1.conf` | PHP-FPM pool |
| `/run/php/php-fpm-myapp-v1.sock` | FPM socket |

Backups land under `/var/sav1/<hostname>/` (see backup section below).

---

## `tb app` — daily usage

```bash
# App URL: https://test-v1.<default webdomain from /conf/webdomain>
tb app sudo/create test-v1 --certbot

tb app sudo/create test-v1 --certbot --webdomain=sub.myotherdomain.tld
tb app sudo/create test-v1 --certbot --webdomain=sub.myotherdomain.tld --www

# Reverse proxy to a backend
tb app sudo/create test-v1 https://127.0.0.1:3000/ --certbot

# Another hosting profile than /conf/mode
tb app sudo/way/proxy/create myapp-v1 http://127.0.0.1:3000 --certbot
```

### Shell completion

Double-TAB on `tb app`, `tb app sudo/remove`, or `tb app sudo/create myapp --` lists commands, apps, and flags. All `tb` modules support completion.

---

## `tb mysql` — MariaDB/MySQL shortcut

`tb mysql` is **not** a separate database engine. It wraps the same tasks you would run with `mysql` / `mariadb` CLI and root credentials (`/root/.my.cnf`), with completion and consistent naming.

`tb app sudo/create` already calls it to create the matching DB user, database, and grants. Use `tb mysql` directly when you need manual DBA work:

```bash
tb mysql sudo/user/list
tb mysql sudo/db/list
tb mysql sudo/db/dump myapp-v1
tb mysql sudo/grant myapp-v1 all myapp-v1
tb mysql query "SHOW DATABASES"
```

Discover commands: `tb mysql` then TAB TAB.

---

## App structure

All apps live under `/apps`:

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
## One name everywhere

For app **test-v1**:

- Linux user: **test-v1**
- MariaDB database: **test-v1**
- MariaDB user: **test-v1**


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

The test-v2 copy is ready.

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

Before deleting files and the system user, `tb app sudo/remove` stops PHP-FPM pools for the app and terminates processes that hold `/apps/<app>` open.

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

Email when a filesystem exceeds a threshold (default **85%**, override with `--threshold=`):

```bash
# m h  dom mon dow   command
*/5 * * * * /bin/tb app sudo/diskalert name@domain.tld
# 30 3 * * * /bin/tb app sudo/diskalert name@domain.tld --threshold=90
```

#### Templates

```bash
tb app sudo/create pma-v1 --certbot --template=pma
tb app sudo/create site-v1 --certbot --template=joomla
```

## WordPress installation example

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
tb app sudo/remove app-v1

# because the
tb app sudo/way/init nginx $email $hostname $php_default_version
# in each installed script fix the mode

### BUT EXISTS ###
tb app sudo/way/  ↹ ↹ (TAB TAB)

sudo/way/apache/remove  sudo/way/hybrid/remove  sudo/way/nginx/create   sudo/way/noweb/create   sudo/way/proxy/create
# show the all way possible and you can mix them when possible

# If you installed the NGINX profile, you can use the PROXY or NOWEB way 
tb app sudo/way/proxy/create app-v1
tb app sudo/way/noweb/create app-v1

# If you installed HYBRID, you can also use PROXY, NGINX, or NOWEB ways when needed
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

![image](https://github.com/xavdp-pro/turbinobash-web/assets/38561912/567acf81-a492-4521-a085-74286ac01569)
![image](https://github.com/xavdp-pro/turbinobash-web/assets/38561912/6cd6f740-db3a-4b95-8914-7503a02ace14)



















