# Dashboards

Classic (Simple XML) dashboards for the lab, matching the index routing in
configs/logharbor (Security events in `wineventlog`, Sysmon events in `sysmon`).

Import into Splunk (admin):
    curl -k -u admin:PASSWORD -X POST \
      "https://localhost:8089/servicesNS/admin/search/data/ui/views" \
      --data-urlencode "name=lh_security_overview" \
      --data-urlencode "eai:data@lh_security_overview.xml"

The previous versions queried index=main sourcetype=_json (the old HEC demo
shape). These query the real indexes and the real field names
(IpAddress coalesced to src_ip).
