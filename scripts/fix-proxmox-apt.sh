#!/bin/bash
# Optional helper: disable Proxmox enterprise APT sources (401 without subscription)
# and add matching download.proxmox.com no-subscription repos. Run as root before tb install on PVE/PBS hosts.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
	echo "Run as root." >&2
	exit 1
fi

. /etc/os-release
CODENAME=${VERSION_CODENAME:-bookworm}

BACKUP_DIR="/root/tb-proxmox-apt-backup-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"
shopt -s nullglob
for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
	[ -f "$f" ] && cp -a "$f" "$BACKUP_DIR/"
done
[ -f /etc/apt/sources.list ] && cp -a /etc/apt/sources.list "$BACKUP_DIR/" || true
echo "Backup: $BACKUP_DIR"

APT_FILES=()
shopt -s nullglob
APT_FILES=(/etc/apt/sources.list.d/*.list)
shopt -u nullglob
[ -f /etc/apt/sources.list ] && APT_FILES+=(/etc/apt/sources.list)

HAD_PVE_ENT=0
HAD_PBS_ENT=0
for f in "${APT_FILES[@]}"; do
	[ -f "$f" ] || continue
	grep -q '^[^#].*enterprise\.proxmox\.com/debian/pve' "$f" 2>/dev/null && HAD_PVE_ENT=1
	grep -q '^[^#].*enterprise\.proxmox\.com/debian/pbs' "$f" 2>/dev/null && HAD_PBS_ENT=1
done
# deb822 .sources (Debian trixie) use URIs: instead of deb lines
shopt -s nullglob
for f in /etc/apt/sources.list.d/*.sources; do
	[ -f "$f" ] || continue
	grep -q 'enterprise\.proxmox\.com/debian/pve' "$f" 2>/dev/null && HAD_PVE_ENT=1
	grep -q 'enterprise\.proxmox\.com/debian/pbs' "$f" 2>/dev/null && HAD_PBS_ENT=1
done
shopt -u nullglob

commented=0
for f in "${APT_FILES[@]}"; do
	[ -f "$f" ] || continue
	if grep -q '^[^#].*enterprise\.proxmox\.com' "$f" 2>/dev/null; then
		sed -i '/^[^#].*enterprise\.proxmox\.com/s/^/# /' "$f"
		commented=1
	fi
done

if [ "$commented" -eq 1 ]; then
	echo "Commented lines pointing to enterprise.proxmox.com"
fi

# Disable deb822 enterprise entries (cannot use sed on single deb line)
shopt -s nullglob
disabled_src=0
for f in /etc/apt/sources.list.d/*.sources; do
	[ -f "$f" ] || continue
	if grep -q 'URIs:.*enterprise\.proxmox\.com' "$f" 2>/dev/null; then
		mv "$f" "${f}.disabled"
		echo "Disabled enterprise sources file: ${f}.disabled"
		disabled_src=1
	fi
done
shopt -u nullglob

if [ "$HAD_PVE_ENT" -eq 1 ] && ! grep -Rqs 'download\.proxmox\.com.*pve-no-subscription' /etc/apt/sources.list.d/ /etc/apt/sources.list 2>/dev/null; then
	echo "deb http://download.proxmox.com/debian/pve ${CODENAME} pve-no-subscription" \
		>/etc/apt/sources.list.d/pve-no-subscription.list
	echo "Added /etc/apt/sources.list.d/pve-no-subscription.list (${CODENAME})"
fi

if [ "$HAD_PBS_ENT" -eq 1 ] && ! grep -Rqs 'download\.proxmox\.com.*pbs-no-subscription' /etc/apt/sources.list.d/ /etc/apt/sources.list 2>/dev/null; then
	echo "deb http://download.proxmox.com/debian/pbs ${CODENAME} pbs-no-subscription" \
		>/etc/apt/sources.list.d/pbs-no-subscription.list
	echo "Added /etc/apt/sources.list.d/pbs-no-subscription.list (${CODENAME})"
fi

echo "Run: apt update"
