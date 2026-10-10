# Demo data — replay real Mordor captures through HEC

Mirror of the SOCAtelier `datasets/splunk-replay` dataset so the Splunk
lab is demoable from this repo alone. The events are real Mordor Windows
captures plus a labeled, schema-accurate 4625 burst; each event carries
its sourcetype, so the lab's props routing lands Security events in
`wineventlog` and Sysmon events in `sysmon`.

Run it:

```bash
# 1. enable HEC and create a token (prints the token value)
sudo LH_PASSWORD='your-admin-password' bash setup/create-hec-token.sh

# 2. replay with timestamps rebased onto now
python3 demo/replay_to_splunk.py demo/events \
    --hec-url https://localhost:8088 --hec-token YOUR_TOKEN --now --insecure
```

`--insecure` skips TLS verification for the lab's self-signed cert.
Verified live on 11/10/2026: 15 events replayed, all five SPL detections
and the three dashboards show data from this dataset.
