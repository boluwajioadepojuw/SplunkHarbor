#!/bin/bash
# SplunkHarbor - open the receiving port and set the forwarder index
set -euo pipefail

say() { printf '%s %s\n' "[lh]" "$*"; }

LH_HOME="/opt/splunk"
LH_PORT="${LH_PORT:-9997}"
LH_INDEX="${LH_INDEX:-win}"

say "writing inputs.conf for the receiver port $LH_PORT"
mkdir -p "$LH_HOME/etc/apps/splunkharbor_receiver/local"
cat > "$LH_HOME/etc/apps/splunkharbor_receiver/local/inputs.conf" <<EOF
[splunktcp://$LH_PORT]
connection_host = ip
index = $LH_INDEX
EOF

say "writing indexes.conf"
cat > "$LH_HOME/etc/apps/splunkharbor_receiver/local/indexes.conf" <<EOF
[$LH_INDEX]
homePath   = \$SPLUNK_DB/$LH_INDEX/db
coldPath   = \$SPLUNK_DB/$LH_INDEX/colddb
thawedPath = \$SPLUNK_DB/$LH_INDEX/thaweddb
EOF

say "opening firewall port (ufw)"
if command -v ufw >/dev/null; then
  ufw allow "$LH_PORT/tcp" || say "ufw rule failed - open $LH_PORT manually"
fi

say "restarting splunk to load the app"
"$LH_HOME/bin/splunk" restart 2>/dev/null || true

say "done - endpoints can now send to <this-host>:$LH_PORT"
