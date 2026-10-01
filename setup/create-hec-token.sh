#!/bin/bash
# SplunkHarbor - enable HEC and create a replay token
set -euo pipefail

# Creates the token the dataset replay needs (SOCAtelier datasets/splunk-replay).
# Bare metal:
#   sudo LH_PASSWORD='your-admin-password' bash setup/create-hec-token.sh
# Docker (compose stack):
#   docker cp setup/create-hec-token.sh <container>:/tmp/
#   docker exec -u root -e LH_PASSWORD='your-admin-password' \
#     <container> bash /tmp/create-hec-token.sh

say() { printf '%s %s\n' "[lh]" "$*"; }

LH_HOME="${SPLUNK_HOME:-/opt/splunk}"
LH_PASSWORD="${LH_PASSWORD:-}"
LH_TOKEN_NAME="${LH_TOKEN_NAME:-lh-replay}"
LH_OUT="${LH_OUT:-/tmp/lh-hec-token.txt}"

[[ -n "$LH_PASSWORD" ]] || { say "set LH_PASSWORD (the Splunk admin password)"; exit 1; }
[[ -x "$LH_HOME/bin/splunk" ]] || { say "splunk CLI not found under $LH_HOME"; exit 1; }

say "enabling the HTTP Event Collector"
"$LH_HOME/bin/splunk" http-event-collector enable \
  -uri https://localhost:8089 -auth "admin:$LH_PASSWORD"

say "creating token $LH_TOKEN_NAME"
"$LH_HOME/bin/splunk" http-event-collector create -name "$LH_TOKEN_NAME" \
  -uri https://localhost:8089 -auth "admin:$LH_PASSWORD" | tee "$LH_OUT"

say "token saved to $LH_OUT"
say "replay with: python3 datasets/splunk-replay/replay_to_splunk.py events --hec-token <token>"
