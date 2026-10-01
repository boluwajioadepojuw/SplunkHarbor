# SplunkHarbor Guide

One-page guide for the lab. The scripts do the heavy lifting; this explains
what each piece is for and how to verify it works.

## What this lab is

Two roles: the Splunk receiver runs on Linux (this machine, Docker), and
the Windows endpoint sends Sysmon and Security logs through the Universal
Forwarder. Together they give you the same pipeline a real SOC L1 watches:
endpoint events land in Splunk, and you hunt with SPL.

Lab reality note: this repo was built on a single Linux machine, so the
live screenshots were produced with the receiver in Docker and Windows-shaped
events (Sysmon EID 1/13, Security 4624/4625) sent through the HTTP Event
Collector. The forwarder path (deploy-forwarder.ps1) is ready for the day a
Windows box is available.

## Setup order

1. Copy `.env.example` to `.env` and set `LH_PASSWORD` (Docker path), or
   download the Splunk .deb from a free splunk.com account (bare-metal path).
2. Docker: `docker compose up -d` - the stack mounts
   `configs/logharbor/local` into the receiver app, so inputs, index
   routing and the five saved searches are live on first boot.
   Bare-metal: run `install-splunk.sh`, then `configure-inputs.sh`
   (deploys the same repo configs and opens TCP 9997).
3. On the Windows endpoint, run `deploy-forwarder.ps1 -SplunkHost <linux-ip>`:
   installs the Universal Forwarder silently, points it at the receiver,
   enables Security/System/Application logs plus Sysmon.
4. Verify: in Splunk search `index=sysmon OR index=wineventlog
   | stats count by host` and you should see the endpoint name.

## The detection part (spl/)

The spl/ folder holds the searches that turn this into a detection lab:

- brute force: failed logons (4625) clustered by source
- encoded powershell: -EncodedCommand or -enc on the command line
- scheduled tasks: schtasks /create from a shell
- lateral movement: network share access (5140) - the event that carries
  ShareName
- persistence: Run key and startup folder writes

Each search file starts with a backtick comment explaining what it catches
and what to tune. The same five searches ship as saved searches in
`configs/logharbor/local/savedsearches.conf` (cron every 5 minutes; the
brute-force search also fires a webhook - replace the placeholder URL).
See spl/triage-walkthrough.md for a worked example: an alert fires, you
confirm it, you scope it, you write it up.

## Index routing

Events land in three indexes: sysmon, wineventlog and powershell
(configs/logharbor/local: props.conf + transforms.conf + indexes.conf).
Searches use the index that matches their source - that keeps every query
scanning only the data it needs.

## Field extraction note

The searches coalesce `src_ip`/`IpAddress` and `user`/`SubjectUserName`,
so they return results with or without the Splunk Add-on for Windows.
The HEC demo path and the rendered-XML forwarder path are both covered by
the sourcetype stanzas in props.conf.

## Why the pieces are named this way

The receiver app is 'splunkharbor_receiver' and the endpoint app is
'splunkharbor_forwarder', so everything this lab owns is visible in one place
under the splunkharbor namespace and easy to tell apart from stock Splunk apps.
