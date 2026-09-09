# Log Sources

The lab ingests telemetry from several Windows log sources. Each one
covers a different layer of endpoint activity.

## Log source overview

| Source | Index | What It Captures | Key Events |
|---|---|---|---|
| **Sysmon** | sysmon | Process, network, file, registry, DNS telemetry | 1, 3, 7, 8, 10, 11, 13, 22, 25 |
| **Windows Security** | wineventlog | Authentication, account management, privilege use | 4624, 4625, 4672, 4688, 4720, 4728, 1102 |
| **Windows System** | wineventlog | Service installation, system state changes | 7045, 7036, 104 |
| **PowerShell** | powershell | Script execution, module loading | 4104, 4103 |

## Why these sources matter

### Sysmon: endpoint visibility

Sysmon extends native Windows logging with process-level detail the
Security log does not have. Without Sysmon you cannot see command-line
arguments, parent processes, file hashes, or DNS queries tied to a
specific process.

Key Sysmon Event IDs:

| Event ID | Name | Detection Use | Attacks Detected |
|---|---|---|---|
| **1** | Process Creation | Full command line, parent-child relationships, file hashes | Mimikatz execution, encoded PowerShell, LOLBins |
| **3** | Network Connection | Outbound/inbound with process context | C2 callbacks, reverse shells, beaconing |
| **7** | Image Load | DLL loading events | DLL injection, DLL side-loading |
| **8** | CreateRemoteThread | Cross-process thread creation | Process injection (Cobalt Strike, Metasploit) |
| **10** | Process Access | Handle opens to other processes | LSASS credential dumping |
| **11** | File Created | File drops with process attribution | Malware payload delivery |
| **12/13** | Registry Modifications | Key creation and value changes | Persistence via run keys, service registration |
| **22** | DNS Query | DNS with process attribution | C2 over DNS, DGA detection, DNS tunneling |
| **25** | Process Tampering | Advanced evasion detection | Process hollowing, herpaderping, ghosting |

### Windows Security log: authentication and access

The Security log is the foundation of any SOC. It tracks who logged in,
what they accessed, and what privileges they used.

Key Security Event IDs:

| Event ID | Description | Why It Matters |
|---|---|---|
| **4624** | Successful Logon | Type 3=network (lateral movement), Type 10=RDP |
| **4625** | Failed Logon | Brute force, password spraying detection |
| **4648** | Explicit Credential Logon | RunAs abuse, credential theft |
| **4672** | Special Privileges Assigned | Admin logon, SeDebugPrivilege (credential dumping) |
| **4688** | New Process Created | Process execution with command line (if audit policy enabled) |
| **4720** | User Account Created | Persistence via new accounts |
| **4724** | Password Reset Attempt | Account takeover |
| **4728/4732/4756** | Member Added to Group | Privilege escalation to Domain/Local Admins |
| **4768** | Kerberos TGT Requested | Golden Ticket (RC4 encryption type) |
| **4769** | Kerberos TGS Requested | Kerberoasting (high volume + RC4) |
| **1102** | Audit Log Cleared | Anti-forensics, almost always malicious |

### Windows System log: services and state

| Event ID | Description | Why It Matters |
|---|---|---|
| **7045** | New Service Installed | Persistence, PsExec indicators |
| **7036** | Service State Changed | Antivirus/EDR stopped = defense evasion |
| **104** | Event Log Cleared | Anti-forensics |

### PowerShell logging: script visibility

| Event ID | Description | Why It Matters |
|---|---|---|
| **4104** | Script Block Logging | Captures deobfuscated scripts, reveals encoded payloads |
| **4103** | Module Logging | Cmdlet execution (Invoke-Mimikatz, Invoke-WebRequest) |

## Splunk input configuration

Logs are forwarded with the Splunk Universal Forwarder. Index-time
routing is defined in
[transforms.conf](../configs/siem-lab/local/transforms.conf). See
[inputs.conf](../configs/siem-lab/local/inputs.conf) for the full
configuration.

## Verification queries

After deploying the forwarders, run these to verify ingestion:

```spl
# Check Sysmon data
index=sysmon | stats count by EventCode | sort -count

# Check Security events
index=wineventlog sourcetype="WinEventLog:Security" | stats count by EventCode | sort -count

# Check PowerShell logging
index=powershell EventCode=4104 | stats count by Computer

# Verify all hosts are reporting
index=* | stats latest(_time) as last_seen by host | eval status=if(last_seen > relative_time(now(), "-15m"), "Active", "Stale")
```

## Audit policy requirements

For full Security log visibility these audit policies must be enabled
on all endpoints:

| Category | Subcategory | Setting |
|---|---|---|
| Account Logon | Credential Validation | Success, Failure |
| Account Management | Security Group Management | Success |
| Account Management | User Account Management | Success, Failure |
| Logon/Logoff | Logon | Success, Failure |
| Object Access | File System | Success, Failure |
| Privilege Use | Sensitive Privilege Use | Success, Failure |
| System | Security State Change | Success |
