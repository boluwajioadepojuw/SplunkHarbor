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

1. Download the Splunk .deb (free account at splunk.com).
2. Run install-splunk.sh on the Linux box: installs Splunk Free, starts it,
   sets the admin password, enables boot start.
3. Run configure-inputs.sh: opens TCP 9997 and creates the 'win' index.
4. On the Windows endpoint, run deploy-forwarder.ps1 -SplunkHost <linux-ip>:
   installs the Universal Forwarder silently, points it at the receiver,
   enables Security/System/Application logs plus Sysmon.
5. Verify: in Splunk search 'index=win | stats count by host' and you should
   see the endpoint name.

## The detection part (spl/)

The spl/ folder holds the searches that turn this into a detection lab:

- brute force: failed logons clustered by source
- encoded powershell: -EncodedCommand or -enc on the command line
- scheduled tasks: schtasks /create from a shell
- lateral movement: SMB/admin-share access attempts
- persistence: Run key and startup folder writes

Each search file has a comment explaining what it catches and what to tune.
See spl/triage-walkthrough.md for a worked example: an alert fires, you
confirm it, you scope it, you write it up.

## Why the pieces are named this way

The receiver app is 'splunkharbor_receiver' and the endpoint app is
'splunkharbor_forwarder', so everything this lab owns is visible in one place
under the splunkharbor namespace and easy to tell apart from stock Splunk apps.
