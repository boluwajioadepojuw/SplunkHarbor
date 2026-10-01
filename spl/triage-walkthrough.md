# Triage walkthrough - encoded PowerShell alert

Worked example: the lab fires on encoded PowerShell. Here is the L1 loop
from alert to write-up, step by step, with the exact searches.

## 1. The alert

Splunk alert (or the saved search "LH - Encoded PowerShell" shipped in
configs/logharbor/local/savedsearches.conf) triggers on EventCode=1 with
-EncodedCommand on the command line. Note host and time.

## 2. Confirm it

```spl
index=sysmon sourcetype="*WinEventLog:Microsoft-Windows-Sysmon/Operational" EventCode=1 host=<host> CommandLine="*EncodedCommand*"
| table _time, Image, ParentImage, User, CommandLine
```

Is this a real execution? Check ParentImage: cmd.exe or powershell.exe as a
parent from a user session is what we expect; a service account running it
is stranger. Decode the payload for the write-up:

Copy the base64 string, then: `echo <b64> | base64 -d`   (Linux) or
`powershell [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('<b64>'))`

## 3. Scope it

What else did that process touch in the surrounding window?

```spl
index=sysmon sourcetype="*WinEventLog:Microsoft-Windows-Sysmon/Operational" EventCode=3 host=<host>
| search _time > relative_time(now(), "-15m")
| stats count by DestinationIp, DestinationPort
```

and check the process tree:

```spl
index=sysmon sourcetype="*WinEventLog:Microsoft-Windows-Sysmon/Operational" EventCode=1 host=<host>
| search _time > relative_time(now(), "-15m")
| table _time, Image, ParentImage, CommandLine
```

## 4. Decide

- No outbound connections and the command was part of a known admin task:
  close as benign, note the false positive in the rule comments.
- Outbound to a new destination or a spawned download: escalate, block the
  destination, isolate the host per the playbook.

## 5. Write it up

Template: host, time window, MITRE techniques (T1059.001, T1027), what the
payload did, what else the process touched, decision, and one tuning note.
That report is your IR doc - the same shape used in the SOCAtelier reports.
