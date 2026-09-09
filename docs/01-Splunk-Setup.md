# Splunk Server Setup

After this guide you will have:

- Splunk Web UI running at `http://localhost:8000` (or the server's IP)
- Three custom indexes (`sysmon`, `wineventlog`, `powershell`)
  receiving forwarded logs
- Universal Forwarders on the Windows endpoints shipping Sysmon,
  Security, System, and PowerShell logs to Splunk over TCP 9997
- The infrastructure the detection queries in `configs/` expect

## What is Splunk Free?

Splunk Enterprise running without a paid license. Same search engine,
indexing, and SPL as the full product. The limits: 500 MB/day indexing
(plenty for a lab), no built-in alerting (saved searches run manually or
on a schedule), and a single admin account. For learning SIEM work none
of that matters. The search and analysis experience is the same one SOC
teams use in production.

## Installation methods

| Method | Best For | Setup Time |
|---|---|---|
| Docker Compose (recommended) | Any Linux host | ~2 minutes |
| Manual install | Learning Linux admin, or no Docker available | ~30 minutes |

Both are documented below. The forwarder step at the end is the same
either way.

## Architecture

```
Windows endpoints                        Splunk server
┌─────────────────────┐                 ┌─────────────────────────┐
│ Sysmon              │                 │ Splunk Free             │
│ Splunk UF           │──TCP:9997──▶    │ Indexer + Search        │
│ (forwards logs)     │                 │ Web UI: :8000           │
└─────────────────────┘                 │ (Docker or bare metal)  │
                                        └─────────────────────────┘
```

### Network requirements

Open these ports on the Splunk server before starting:

| Port | Protocol | Direction | Purpose |
|---|---|---|---|
| 8000 | TCP | Inbound | Splunk Web UI |
| 9997 | TCP | Inbound | Forwarder data (endpoints to Splunk) |
| 8089 | TCP | Inbound | Management API (optional for basic use) |

---

## Option A: Docker Compose (recommended)

### Prerequisites

- Docker Engine + Docker Compose plugin installed (Step A0)
- At least 4 GB RAM available
- Network reachability to the Windows endpoints

### Step A0: install Docker

Ubuntu / Debian:

```bash
# 1. Remove old packages
sudo apt remove docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc 2>/dev/null

# 2. Prerequisites and Docker's GPG key
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 3. Docker's repository
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# 4. Install Docker Engine + Compose plugin
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5. Add your user to the docker group
sudo usermod -aG docker $USER

# 6. Log out and back in for the group change to take effect
```

Verify:

```bash
docker --version
docker compose version
docker run --rm hello-world
# Expected: "Hello from Docker!"
```

### Step A1: set up the deployment directory

Create a directory on the server (name it anything) with this
structure:

```
~/splunk-lab/
├── docker-compose.yml     (from this repo's root)
├── .env                   (your password, created from .env.example)
└── configs/
    └── siem-lab/          (mounted as a Splunk app)
        ├── app.conf
        └── local/
            ├── inputs.conf
            ├── props.conf
            ├── transforms.conf
            └── indexes.conf
```

Why a Splunk app instead of individual files: the Splunk Docker image
uses Ansible to provision configs at startup, and Ansible does atomic
file renames that fail on Docker bind-mounted files (EBUSY). Mounting a
whole directory as a Splunk app avoids that, and Splunk merges app
configs on top of system defaults automatically.

```bash
mkdir -p ~/splunk-lab/configs

# Copy the repo files into place, then:
cd ~/splunk-lab
cp .env.example .env

# Edit .env and set SPLUNK_PASSWORD to your own password.
# .env is in .gitignore, so the password never gets committed.
```

### Step A2: start Splunk

```bash
docker compose up -d
```

Docker will pull the `splunk/splunk:latest` image, accept the license
(configured in the compose file), mount the configs app from
`configs/siem-lab/`, expose ports 8000/9997/8089, and create persistent
volumes so data survives restarts.

Watch the startup:

```bash
docker compose logs -f splunk
```

Splunk takes 60-90 seconds to start. Wait until you see:

```
Ansible playbook complete, will begin streaming splunkd_stderr.log
```

### Step A3: verify

The three indexes are created automatically from `indexes.conf`. No
manual step needed.

1. Open `http://localhost:8000` (or the server IP)
2. Log in with `admin` and the password from `.env`
3. Settings > Indexes: `sysmon`, `wineventlog`, `powershell` exist
4. Settings > Forwarding and Receiving > Receive data: port 9997 listed

Why separate indexes: search performance (query only what you need),
retention control (different retention per log type), and access
control in enterprise Splunk.

| Index | What goes in |
|---|---|
| `sysmon` | Sysmon telemetry: process, network, registry, DNS events |
| `wineventlog` | Windows Security, System, and Application logs |
| `powershell` | PowerShell Script Block and Module logging |

```bash
docker compose ps
# Should show: splunk-siem ... Up (healthy)

# List indexes via the CLI inside the container
docker exec -u splunk splunk-siem /opt/splunk/bin/splunk list index -auth admin:$(grep SPLUNK_PASSWORD .env | cut -d= -f2)
```

### Docker Compose cheat sheet

| Command | What It Does |
|---|---|
| `docker compose up -d` | Start Splunk in background |
| `docker compose down` | Stop Splunk, data preserved in volumes |
| `docker compose down -v` | Stop and delete all data (fresh start) |
| `docker compose logs -f splunk` | Watch live logs |
| `docker compose ps` | Check container status |
| `docker compose restart` | Restart Splunk |
| `docker exec -it splunk-siem bash` | Shell inside the container |

Use `down -v` only when you want a completely fresh install. It deletes
indexed data, saved searches, and dashboards.

---

## Option B: manual install (Ubuntu Server)

Use this when you want the traditional sysadmin path or Docker is not
available.

### Prerequisites

- Ubuntu Server 22.04+, 2 CPU, 4 GB+ RAM, 50 GB disk
- Splunk Free installer (requires a free Splunk account)
- The `.deb` package matching your CPU: `uname -m` says `x86_64` means
  amd64, `aarch64` means arm64

### Step B1: prepare Ubuntu

```bash
sudo apt update && sudo apt upgrade -y

free -h          # 4GB+ RAM
df -h /          # 50GB+ disk
uname -m         # x86_64 -> amd64 .deb | aarch64 -> arm64 .deb
```

### Step B2: install Splunk

Download the Splunk Enterprise `.deb` from the official site, get it
onto the VM (scp or shared folder), then run the installer script:

```bash
sudo SPLUNK_ADMIN_PASSWORD='YourSecurePassword123!' ./setup/01-Install-Splunk.sh
```

The script handles package installation, license acceptance, admin
credentials, boot-start, the receiving port 9997, and UFW firewall
rules.

Manual alternative:

```bash
sudo dpkg -i splunk-*.deb
sudo /opt/splunk/bin/splunk start --accept-license
sudo /opt/splunk/bin/splunk enable boot-start
sudo /opt/splunk/bin/splunk enable listen 9997
```

### Step B3: configure inputs and indexes

```bash
sudo ./setup/02-Configure-Inputs.sh
```

The script creates the three indexes and deploys the config files from
`configs/siem-lab/local/`:

| Config File | Purpose |
|---|---|
| `inputs.conf` | Listen on TCP 9997 for forwarded data |
| `props.conf` | How Splunk parses each log type |
| `transforms.conf` | Route logs to the right index by sourcetype |
| `indexes.conf` | Create `sysmon`, `wineventlog`, `powershell` |

Manual alternative:

```bash
sudo /opt/splunk/bin/splunk add index sysmon
sudo /opt/splunk/bin/splunk add index wineventlog
sudo /opt/splunk/bin/splunk add index powershell

sudo cp configs/siem-lab/local/inputs.conf /opt/splunk/etc/system/local/
sudo cp configs/siem-lab/local/props.conf /opt/splunk/etc/system/local/
sudo cp configs/siem-lab/local/transforms.conf /opt/splunk/etc/system/local/
sudo cp configs/siem-lab/local/indexes.conf /opt/splunk/etc/system/local/

sudo /opt/splunk/bin/splunk restart
```

`system/local` is the highest-priority config location that persists
across upgrades.

### Step B4: verify

1. Open `http://<splunk-server-ip>:8000`, log in with `admin` and your
   password
2. Settings > Forwarding and Receiving > Receive data: port 9997 listed
3. Settings > Indexes: the three indexes exist

```bash
sudo /opt/splunk/bin/splunk status
sudo netstat -tlnp | grep 9997

# Firewall, if the ports are not open:
sudo ufw allow 8000/tcp   # Web UI
sudo ufw allow 9997/tcp   # Forwarder data
sudo ufw allow 8089/tcp   # Management API (optional)
sudo ufw enable
sudo ufw reload
```

Always verify the receiver before configuring the senders. If the
server is not listening, forwarders fail silently and you debug the
wrong end.

---

## Deploy forwarders on Windows endpoints

The steps above were on the Splunk server. Everything below happens on
the Windows endpoints. The forwarders do not care how Splunk runs, they
just send data to port 9997.

The Splunk Universal Forwarder (UF) is a lightweight agent on each
Windows machine that ships its logs to the Splunk server. Sysmon and
Windows generate events locally; the UF is what delivers them.

### Pre-flight checks

**1. Sysmon is installed and running**

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 1

# Success = Sysmon installed and generating events
# "No events were found" = installed, no activity yet (fine)
# "There is not an event log" = Sysmon NOT installed
```

**2. Network connectivity to the Splunk server**

```powershell
Test-NetConnection -ComputerName 192.168.10.10 -Port 9997
# Expected: TcpTestSucceeded : True
```

If it fails: is Splunk running, is the firewall open, are the machines
on the same network?

### Download the forwarder

Download the Splunk Universal Forwarder `.msi` (Windows 64-bit) from
the official Splunk download page, then copy it to each Windows
endpoint.

### Run the deployment script

```powershell
# On each Windows endpoint (run as Administrator)
cd $HOME
mkdir -p splunk-forwarder-setup
cd splunk-forwarder-setup
.\03-Deploy-Forwarder.ps1 -SplunkServerIP "192.168.10.10" -InstallerPath "path\to\splunkforwarder.msi"
```

The script configures these log channels:

| Log Channel | What It Collects |
|---|---|
| `Microsoft-Windows-Sysmon/Operational` | Sysmon process, network, file, registry, DNS events |
| `Security` | Authentication, account management, privilege use |
| `System` | Service installation, system state changes |
| `Microsoft-Windows-PowerShell/Operational` | Script Block logging (deobfuscated scripts) |
| `Windows PowerShell` | Classic PowerShell engine events |

Manual alternative:

```powershell
msiexec /i splunkforwarder.msi SPLUNK_APP_NAME=SplunkForwarder AGREETOLICENSE=Yes /quiet

$outputsConf = @"
[tcpout]
defaultGroup = lab-indexer

[tcpout:lab-indexer]
server = 192.168.10.10:9997
"@
$outputsConf | Out-File -FilePath "C:\Program Files\SplunkUniversalForwarder\etc\system\local\outputs.conf" -Encoding ASCII

Start-Service SplunkForwarder
```

### Verify data is flowing

```spl
index=* | stats count by index, host, sourcetype
index=sysmon | stats count by EventCode | sort -count
index=wineventlog sourcetype="WinEventLog:Security" | head 10
```

Forwarders usually send data within 30-60 seconds. If nothing shows
after 2 minutes, go through the troubleshooting table.

---

## Troubleshooting

| Issue | Check | Fix |
|---|---|---|
| Web UI not loading | `sudo /opt/splunk/bin/splunk status` or `docker compose ps` | Restart Splunk or `docker compose restart` |
| Forwarders not connecting | `netstat -tlnp \| grep 9997` | Manual: `sudo ufw allow 9997/tcp`. Docker: `docker compose down && docker compose up -d` |
| No data in indexes | `index=* \| stats count by index, host` | On the endpoint, check `outputs.conf` under `C:\Program Files\SplunkUniversalForwarder\etc\system\local\` and confirm the `server =` line matches the Splunk IP |
| Search returns nothing | Forwarder shows "Active forwards" but `index=*` is empty | Set the time picker to "All time". The default "Last 24 hours" hides older events |
| High disk usage | Settings > Indexes, check sizes | Add `maxTotalDataSizeMB = 10240` to each stanza in `indexes.conf`, restart Splunk |
| Wrong architecture (manual) | `uname -m` says `aarch64` but amd64 was installed | Re-download the arm64 `.deb` |
| Container won't start | `docker compose logs splunk` | Common cause: password shorter than 8 chars. Fix `.env`, then `docker compose down -v && docker compose up -d` |
| Crash-loop with EBUSY errors | `docker compose logs splunk` shows "Device or resource busy" | Individual config files are bind-mounted. Mount the whole app directory instead (see `configs/siem-lab/`) |
| Configs not taking effect | `docker exec -u splunk splunk-siem /opt/splunk/bin/splunk btool inputs list --debug` | Confirm `configs/siem-lab/` exists next to `docker-compose.yml` with `app.conf` and `local/`. Missing directory means an empty mount |
| Port already in use (8089) | `sudo lsof -i :8089` | `sudo kill <PID>`, restart. Orphan processes happen when a container crashes |

### No data after forwarder install, step by step

**Step 1: is the forwarder service running?** (Windows endpoint)

```powershell
Get-Service SplunkForwarder
# If stopped: Start-Service SplunkForwarder
```

**Step 2: is the forwarder connected to the Splunk server?**

```powershell
cd "C:\Program Files\SplunkUniversalForwarder\bin"
.\splunk list forward-server
# Look for your Splunk IP under "Active forwards"
```

**Step 3: is the receiving port open on the Splunk server?**

```bash
sudo ss -tlnp | grep 9997
```

If nothing shows, enable it in Splunk Web: Settings > Forwarding and
Receiving > Receive data > New Receiving Port > 9997.

**Step 4: can the Windows endpoint reach port 9997?**

```powershell
Test-NetConnection -ComputerName <SPLUNK_IP> -Port 9997
# TcpTestSucceeded should be True
```

**Step 5: check the search time range**

In Search & Reporting, switch the time picker from "Last 24 hours" to
"All time", then run `index=*` again. The default range is a common
reason data looks missing.

---

## Security considerations

Lab defaults, and what changes in production:

| Area | Lab Default | Production Equivalent |
|---|---|---|
| Forwarder-to-indexer traffic | Unencrypted S2S on 9997 | TLS via `server.conf` and `outputs.conf` |
| Splunk Web UI | HTTP on 8000 | HTTPS via `web.conf` with a TLS certificate |
| Forwarder admin password | Default in the deploy script | Unique strong password per endpoint |
| Splunk admin access | Single admin account | Role-based access control (licensed Splunk) |
| Network isolation | Lab VMs on a shared network | SIEM on a management VLAN, port 8000 restricted |

SOC interviews often ask about SIEM hardening. Knowing that forwarder
traffic is unencrypted by default, and how to fix it, shows you
understand the infrastructure beyond "it works".

---

## Next steps

- [Log Sources](02-Log-Sources.md): what each source provides
- [Glossary](GLOSSARY.md): terms used in this lab
- Write and test SPL detections against the live data
