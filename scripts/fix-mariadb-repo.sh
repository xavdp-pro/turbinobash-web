#!/bin/bash
# Rewrite /etc/apt/sources.list.d/mariadb.list to use deb.mariadb.org
# with a version/suite pair that has a Release file. Run as root.

set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run as root." >&2; exit 1; }

# Do not call apt before rewriting mariadb.list (dpkg lock would skip the fix).
mkdir -p /etc/apt/keyrings
command -v curl >/dev/null 2>&1 || { echo "Install curl first." >&2; exit 1; }
[ -f /etc/apt/keyrings/mariadb-keyring.pgp ] || curl -fsSL -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'

. /etc/os-release

pick_mariadb_repo_ubuntu() {
	local ubuntu_codename="$1"
	local selected_version=""
	local selected_suite=""
	local version_candidates=""

	# Target matrix:
	# - focal (20.04): 10.6 LTS
	# - jammy (22.04): 10.11 LTS
	# - noble (24.04): 11.4 LTS
	case "$ubuntu_codename" in
		focal) version_candidates="10.6 10.11 11.4" ;;
		jammy) version_candidates="10.11 11.4 10.6" ;;
		noble) version_candidates="11.4 10.11 10.6" ;;
		*)     version_candidates="11.4 10.11 10.6" ;;
	esac

	local suite_candidates="$ubuntu_codename noble jammy focal"
	local version candidate

	for version in $version_candidates; do
		for candidate in $suite_candidates; do
			if curl -fsSIL -o /dev/null "https://deb.mariadb.org/${version}/ubuntu/dists/${candidate}/Release" 2>/dev/null; then
				selected_version="$version"
				selected_suite="$candidate"
				break 2
			fi
		done
	done

	[ -z "$selected_version" ] && return 1
	echo "${selected_version}:${selected_suite}"
}

pick_mariadb_repo_debian() {
	local debian_codename="$1"
	local selected_version=""
	local selected_suite=""
	local version_candidates=""

	# Target matrix:
	# - bullseye (11): 10.11 LTS
	# - bookworm (12): 11.4 LTS
	# - trixie (13): 11.8
	case "$debian_codename" in
		bullseye) version_candidates="10.11 11.4 11.8" ;;
		bookworm) version_candidates="11.4 10.11 11.8" ;;
		trixie)   version_candidates="11.8 11.4 10.11" ;;
		*)        version_candidates="11.8 11.4 10.11" ;;
	esac

	local suite_candidates="$debian_codename trixie bookworm bullseye"
	local version candidate

	for version in $version_candidates; do
		for candidate in $suite_candidates; do
			if curl -fsSIL -o /dev/null "https://deb.mariadb.org/${version}/debian/dists/${candidate}/Release" 2>/dev/null; then
				selected_version="$version"
				selected_suite="$candidate"
				break 2
			fi
		done
	done

	[ -z "$selected_version" ] && return 1
	echo "${selected_version}:${selected_suite}"
}

if [ "$ID" = "ubuntu" ]; then
	MARIADB_PICK=$(pick_mariadb_repo_ubuntu "${VERSION_CODENAME}") || {
		echo "No compatible MariaDB upstream repo found for Ubuntu codename '${VERSION_CODENAME}'." >&2
		exit 1
	}
	MARIADB_VERSION=${MARIADB_PICK%%:*}
	MARIADB_SUITE=${MARIADB_PICK##*:}
	echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://deb.mariadb.org/${MARIADB_VERSION}/ubuntu ${MARIADB_SUITE} main" >/etc/apt/sources.list.d/mariadb.list
else
	MARIADB_PICK=$(pick_mariadb_repo_debian "${VERSION_CODENAME}") || {
		echo "No compatible MariaDB upstream repo found for Debian codename '${VERSION_CODENAME}'." >&2
		exit 1
	}
	MARIADB_VERSION=${MARIADB_PICK%%:*}
	MARIADB_SUITE=${MARIADB_PICK##*:}
	echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://deb.mariadb.org/${MARIADB_VERSION}/debian ${MARIADB_SUITE} main" >/etc/apt/sources.list.d/mariadb.list
fi

echo "Wrote /etc/apt/sources.list.d/mariadb.list (version=${MARIADB_VERSION:-11.4}, suite=${MARIADB_SUITE}, host=deb.mariadb.org)"
cat /etc/apt/sources.list.d/mariadb.list
