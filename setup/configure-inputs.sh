#!/bin/bash
# SplunkHarbor - deploy the repo app config and open the receiving port
set -euo pipefail

# Deploys configs/logharbor/local/*.conf into the splunkharbor_receiver
# app: inputs (TCP 9997), props/transforms (parsing + index routing),
# indexes (sysmon / wineventlog / powershell) and the five saved searches.
# Run from the repo root:
#   sudo bash setup/configure-inputs.sh

say() { printf '%s %s\n' "[lh]" "$*"; }

LH_HOME="/opt/splunk"
LH_APP="$LH_HOME/etc/apps/splunkharbor_receiver/local"
LH_PORT="${LH_PORT:-9997}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CONF_SRC="$REPO_ROOT/configs/logharbor/local"

[[ -d "$CONF_SRC" ]] || { say "configs not found under $REPO_ROOT - run from the repo root"; exit 1; }

say "deploying app config to $LH_APP"
mkdir -p "$LH_APP"
cp "$CONF_SRC"/*.conf "$LH_APP/"

say "ensuring the receiver listens on $LH_PORT"
if ! grep -q "splunktcp://$LH_PORT" "$LH_APP/inputs.conf"; then
  cat >> "$LH_APP/inputs.conf" <<EOF
[splunktcp://$LH_PORT]
disabled = false
EOF
fi

say "opening firewall port (ufw)"
if command -v ufw >/dev/null; then
  ufw allow "$LH_PORT/tcp" || say "ufw rule failed - open $LH_PORT manually"
fi

say "restarting splunk to load the app"
"$LH_HOME/bin/splunk" restart 2>/dev/null || true

say "done - endpoints can now send to <this-host>:$LH_PORT"
say "indexes: sysmon, wineventlog, powershell (see configs/logharbor/local)"
