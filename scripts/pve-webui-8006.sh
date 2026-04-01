#!/bin/bash
# Start Proxmox VE web UI (HTTPS port 8006) when proxmox-ve is already installed.
# Does NOT install the full hypervisor stack — see https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian
# Run as root on a Proxmox VE node.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
	echo "Run as root." >&2
	exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
	echo "systemd not found; this script targets Proxmox VE / Debian with systemd." >&2
	exit 1
fi

if ! systemctl list-unit-files pveproxy.service 2>/dev/null | grep -q pveproxy; then
	echo "pveproxy is not installed. This host does not have Proxmox VE (port 8006)."
	echo "Proxmox Backup Server only uses port 8007 — that is normal on a PBS-only machine."
	echo "To install PVE, follow: https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian"
	exit 2
fi

echo "Enabling and starting PVE web services..."
systemctl enable pveproxy pvedaemon pvestatd spiceproxy 2>/dev/null || true
systemctl restart pvedaemon || true
systemctl restart pveproxy

sleep 1
systemctl --no-pager status pveproxy || true

echo ""
if ss -tlnp 2>/dev/null | grep -q ':8006 '; then
	echo "Port 8006 is listening. Open: https://$(hostname -f):8006/"
else
	echo "pveproxy is running but nothing listens on 8006 yet — check journal:"
	echo "  journalctl -u pveproxy -n 80 --no-pager"
fi
