#!/bin/bash
# Diagnose why Proxmox web UIs (8006 PVE, 8007 PBS) listen but are unreachable remotely.
# Run as root on the Proxmox/PBS host.

set -euo pipefail

echo "=== Listening sockets (8006 / 8007) ==="
ss -tlnp 2>/dev/null | grep -E ':8006|:8007' || true

echo ""
echo "=== Local HTTP response (should be 200 or 301/302) ==="
for url in "https://127.0.0.1:8006/" "https://[::1]:8006/" "https://127.0.0.1:8007/" "https://[::1]:8007/"; do
	echo "--- curl -kI $url ---"
	curl -kIsS --connect-timeout 3 "$url" 2>&1 | head -5 || echo "(failed)"
done

echo ""
echo "=== pve-firewall (if installed) ==="
if command -v pve-firewall >/dev/null 2>&1; then
	pve-firewall status 2>&1 || true
else
	echo "pve-firewall not in PATH (ok on PBS-only)"
fi

echo ""
echo "=== nftables / iptables (first rules) ==="
command -v nft >/dev/null && nft list ruleset 2>/dev/null | head -40 || true
iptables -L INPUT -n -v 2>/dev/null | head -15 || true

echo ""
echo "=== Hints ==="
echo "1) If curl to 127.0.0.1 works but browser from Internet fails: open 8006/tcp (and 8007 if needed) in:"
echo "   - OVH / provider security group / vRack firewall"
echo "   - Datacenter -> Firewall in Proxmox (or host iptables)"
echo "2) Try exact URL: https://YOUR_PUBLIC_IP:8006/ (accept self-signed cert warning)"
echo "3) IPv6-only listen: test from a client with IPv6 or force IPv4 bind in PVE (see wiki)."
