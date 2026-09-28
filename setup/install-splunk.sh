#!/bin/bash
# SplunkHarbor - install the Splunk receiver on Ubuntu
set -euo pipefail

# What this does:
#   1. checks we run as root and a .deb is available
#   2. installs the package with dpkg
#   3. starts splunkd with the free license and accepts the EULA
#   4. enables start on boot
#
# Usage:
#   sudo LH_PASSWORD='pick-a-password' LH_DEB=./splunk-9.x-linux.deb bash install-splunk.sh

say()  { printf '%s %s\n' "[lh]" "$*"; }
fail() { printf '%s %s\n' "[lh][fail]" "$*" >&2; exit 1; }

LH_PASSWORD="${LH_PASSWORD:-}"
LH_DEB="${LH_DEB:-}"
LH_HOME="/opt/splunk"

say "checking preconditions"
[[ $EUID -eq 0 ]] || fail "run as root: sudo bash $0"
[[ -n "$LH_PASSWORD" ]] || fail "set LH_PASSWORD (8+ chars)"
[[ -n "$LH_DEB" && -f "$LH_DEB" ]] || fail "set LH_DEB to the Splunk .deb you downloaded from splunk.com"
command -v dpkg >/dev/null || fail "dpkg not found"

say "installing package $LH_DEB"
dpkg -i "$LH_DEB" || apt-get -f install -y

say "first start (accepts license, applies free tier)"
"$LH_HOME/bin/splunk" start --accept-license --answer-yes --no-prompt --seed-passwd "$LH_PASSWORD" 2>/dev/null \
  || "$LH_HOME/bin/splunk" start --accept-license --answer-yes --no-prompt

say "enabling start on boot"
"$LH_HOME/bin/splunk" enable boot-start -user root --accept-license 2>/dev/null || true

say "done - web UI on http://<this-host>:8000 (admin / your LH_PASSWORD)"
say "next: run configure-inputs.sh to open the receiver port"
