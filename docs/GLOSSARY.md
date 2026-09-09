# Glossary

Quick reference for the terms used in this project. Definitions are
plain, with a lab example where it helps.

---

**Alert**: A notification raised when a detection rule matches
suspicious activity. Alerts are what SOC analysts triage all day.
Example: the LSASS access detection fires when a process opens LSASS
with suspicious access flags.

**Atomic Red Team**: A free library of small test scripts ("atomics")
that simulate single ATT&CK techniques. Used to confirm that a detection
rule actually fires. Example: running the T1003.001 atomic to verify the
LSASS dump detection.

**Beaconing**: A pattern where a compromised machine checks in with a
command-and-control server at regular intervals. Example: a workstation
connecting to the same external IP every 60 seconds.

**Benign True Positive (BTP)**: An alert where the rule logic matched
correctly, but the activity is legitimate. The rule worked; the activity
was not a threat. Example: a service-creation detection firing when IT
deploys monitoring software.

**C2 (Command and Control)**: The infrastructure an attacker uses to
talk to compromised systems. Commands flow out, stolen data flows back.
Example: a beacon calling back to a team server on TCP 443.

**Correlation Rule**: A detection rule that combines events from
multiple sources, or matches a sequence over time. Example: a rule that
fires when a user fails 5 logins in 2 minutes (4625), then succeeds
(4624), then creates an admin account (4720).

**DCSync**: An attack where the adversary impersonates a domain
controller and requests password hash replication from Active
Directory. No code runs on the DC itself. Example: Mimikatz
`lsadump::dcsync` against the Administrator account.

**Detection Rule**: A defined search query that runs on a schedule to
find malicious patterns in log data. The basic building block of
SIEM-based monitoring. Example: an SPL query looking for Sysmon Event ID
10 against LSASS.

**DGA (Domain Generation Algorithm)**: Malware that generates many
random-looking domain names to reach its C2 server. Harder to block by
domain name alone. Example: a new random domain every day, with the
attacker registering just one.

**EDR (Endpoint Detection and Response)**: Software on endpoints that
monitors activity, detects threats, and can respond automatically, for
example by isolating a machine. Example: CrowdStrike Falcon, Microsoft
Defender for Endpoint, SentinelOne.

**Event ID**: A numeric code that identifies the type of a Windows log
entry. Example: Sysmon Event ID 1 is process creation, Windows Security
4624 is successful logon.

**False Positive (FP)**: An alert that fires on activity that is not
malicious. Tuning false positives down is a core SOC task; too many
cause alert fatigue. Example: antivirus accessing LSASS during a scan
triggers the dump detection.

**Golden Ticket**: A forged Kerberos Ticket Granting Ticket built from
the KRBTGT account hash. Effectively domain admin, and the ticket can
last for years. Example: Mimikatz creating a golden ticket after DCSync.

**GPO (Group Policy Object)**: A set of Active Directory rules that
controls the configuration of machines and users in a domain. In this
lab, GPOs deploy Sysmon configs and forwarders to endpoints.

**Index (Splunk)**: A data store in Splunk where ingested logs are
kept. Different log types go into different indexes. This lab uses
`index=sysmon`, `index=wineventlog`, and `index=powershell`.

**IOC (Indicator of Compromise)**: A piece of forensic evidence that
suggests compromise. A specific, observable artifact. Example: a known
malicious IP, a malware file hash, a backdoor registry key.

**Kerberoasting**: Requesting Kerberos service tickets for service
accounts, then cracking them offline to recover plaintext passwords.
Works because service tickets are encrypted with the service account's
password hash.

**KQL (Kusto Query Language)**: The query language used by Microsoft
Sentinel and Defender. The same role SPL plays for Splunk. Example:
`SecurityEvent | where EventID == 4625 | summarize count() by TargetAccount`.

**Lateral Movement**: When an attacker moves from one compromised
system to another inside the network to reach the target. One of the
ATT&CK tactics. Example: PsExec against a file server after compromising
a workstation.

**LOLBin (Living Off the Land Binary)**: A legitimate, pre-installed
Windows binary misused for attack. Signed Microsoft tools, so they often
pass application controls. Example: certutil.exe downloading a payload,
or rundll32.exe running a malicious DLL.

**LSASS (Local Security Authority Subsystem Service)**: The Windows
process (lsass.exe) that handles authentication and holds credentials in
memory. One of the most targeted processes: dumping its memory can
reveal passwords, hashes, and Kerberos tickets.

**MITRE ATT&CK**: A public knowledge base of adversary tactics and
techniques built from real-world observations. Columns are tactics
(goals), rows are techniques (methods). Every detection rule in this lab
maps to an ATT&CK technique. Example: LSASS dump detection maps to
T1003.001.

**MITRE ATT&CK Tactic**: The adversary's goal, the "why". There are 14
tactics in the Enterprise matrix, from Initial Access to Impact.
Example: Credential Access is a tactic.

**MITRE ATT&CK Technique**: The specific method used to reach a goal,
the "how". Each technique has an ID. Example: T1003 OS Credential
Dumping.

**Persistence**: Techniques that keep access to a compromised system
across restarts or credential changes. Example: a registry Run key entry
that launches on every logon.

**Privilege Escalation**: Techniques that gain higher permissions on a
system or in a network. Example: adding a compromised account to the
Domain Admins group.

**PsExec**: A Sysinternals tool for running commands on remote Windows
systems. Legitimate for admins, heavily used by attackers for lateral
movement. Example: `psexec.exe \\target-server cmd.exe`.

**Sigma**: A vendor-neutral open standard for detection rules in YAML.
Sigma rules convert to SPL, KQL, and other SIEM query languages.

**SIEM (Security Information and Event Management)**: A platform that
collects, normalizes, and analyzes security logs across an organization
to detect threats and support investigations. Example: Splunk, Microsoft
Sentinel, Elastic Security.

**SOAR (Security Orchestration, Automation, and Response)**: A platform
that automates repetitive SOC tasks: enriching alerts, isolating hosts,
creating tickets. Pairs with a SIEM to speed up response.

**SOC (Security Operations Center)**: The team responsible for
monitoring security posture, triaging alerts, investigating incidents,
and coordinating response. The SOC analyst's day: triage SIEM alerts,
investigate, escalate or close, tune rules.

**Sourcetype**: A Splunk classification that identifies the format of
incoming data, so Splunk knows how to parse it into fields. Example:
`sourcetype=XmlWinEventLog` is Windows Event Log in XML.

**SPL (Search Processing Language)**: Splunk's query language for
searching, filtering, transforming, and visualizing log data. Example:
`index=sysmon EventCode=1 | stats count by Image | sort -count`.

**Sysmon (System Monitor)**: A Microsoft Sysinternals service that logs
detailed telemetry: process creation, network connections, file changes,
registry changes, DNS. Much richer than native Windows logging.
Example: Event ID 1 captures process creation with full command line,
parent process, and file hashes.

**True Positive (TP)**: An alert that correctly identifies real
malicious activity. The goal of every detection rule. Example: the LSASS
detection fires on a real Mimikatz run and the investigation confirms
credential theft.

**TTP (Tactics, Techniques, and Procedures)**: The behaviors and
methods attackers use. More durable than IOCs: an attacker changes IPs
easily, changing methodology is harder. Example: "PsExec for lateral
movement after credential dumping" is a TTP pattern.

**Tuning**: Refining detection rules to cut false positives while
keeping true detections. Exclusions for known legitimate activity,
threshold adjustments, narrower scope. Example: excluding the antivirus
process from the LSASS access detection.

**Universal Forwarder (UF)**: A lightweight Splunk agent that collects
logs on an endpoint and ships them to the indexer. It does not analyze,
it just forwards. Example: a UF on a domain controller sending Sysmon
and Security events to Splunk over TCP 9997.

**WEF (Windows Event Forwarding)**: A built-in Windows mechanism for
collecting event logs from many machines centrally, without third-party
agents. An alternative to the Universal Forwarder.

**WMI (Windows Management Instrumentation)**: A Windows administration
framework for querying systems and running commands locally or remotely.
Legitimate admin tool, frequently abused for recon and lateral
movement.
