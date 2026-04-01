#!/bin/bash
# Rewrite /etc/apt/sources.list.d/mariadb.list to use deb.mariadb.org and a suite
# that has a Release file (bookworm fallback when trixie is missing). Run as root.

set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run as root." >&2; exit 1; }

# Do not call apt before rewriting mariadb.list (dpkg lock would skip the fix).
mkdir -p /etc/apt/keyrings
command -v curl >/dev/null 2>&1 || { echo "Install curl first." >&2; exit 1; }
[ -f /etc/apt/keyrings/mariadb-keyring.pgp ] || curl -fsSL -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'

. /etc/os-release

if [ "$ID" = "ubuntu" ]; then
	MARIADB_SUITE=
	for candidate in "$VERSION_CODENAME" noble jammy; do
		if curl -fsSIL -o /dev/null "https://deb.mariadb.org/11.4/ubuntu/dists/${candidate}/Release" 2>/dev/null; then
			MARIADB_SUITE=$candidate
			break
		fi
	done
	[ -z "$MARIADB_SUITE" ] && MARIADB_SUITE=jammy
	echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://deb.mariadb.org/11.4/ubuntu ${MARIADB_SUITE} main" >/etc/apt/sources.list.d/mariadb.list
else
	MARIADB_SUITE=
	for candidate in "$VERSION_CODENAME" bookworm bullseye; do
		if curl -fsSIL -o /dev/null "https://deb.mariadb.org/11.4/debian/dists/${candidate}/Release" 2>/dev/null; then
			MARIADB_SUITE=$candidate
			break
		fi
	done
	[ -z "$MARIADB_SUITE" ] && MARIADB_SUITE=bookworm
	echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://deb.mariadb.org/11.4/debian ${MARIADB_SUITE} main" >/etc/apt/sources.list.d/mariadb.list
fi

echo "Wrote /etc/apt/sources.list.d/mariadb.list (suite=${MARIADB_SUITE}, host=deb.mariadb.org)"
cat /etc/apt/sources.list.d/mariadb.list
