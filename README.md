# Developer CLI & Linux Reference Guide

A comprehensive, production-ready reference guide covering **WSL 2 administration**, essential **Linux system & storage management**, and indispensable **Bash & CLI developer workflows**.

---

## Table of Contents
1. [WSL 2 Administration & Lifecycle](#1-wsl-2-administration--lifecycle)
   - [Instance Lifecycle Management](#instance-lifecycle-management)
   - [Export, Backup & Import Custom Distros](#export-backup--import-custom-distros)
   - [Configuration & Resource Tuning (`.wslconfig` & `wsl.conf`)](#configuration--resource-tuning)
   - [Disk Maintenance & Compaction](#disk-maintenance--compaction)
   - [Windows-WSL Interoperability](#windows-wsl-interoperability)
2. [Essential Linux for Developers](#2-essential-linux-for-developers)
   - [Storage & Network Drive Mounting (`/etc/fstab`)](#storage--network-drive-mounting-etcfstab)
   - [Process Management & Diagnostics](#process-management--diagnostics)
   - [File Operations, Navigation & Search](#file-operations-navigation--search)
   - [User Permissions & Security](#user-permissions--security)
   - [Systemd Services & Logs](#systemd-services--logs)
   - [Network Troubleshooting & Connectivity](#network-troubleshooting--connectivity)
3. [Universal CLI & Bash Developer Productivity](#3-universal-cli--bash-developer-productivity)
   - [Text Processing & Stream Editing](#text-processing--stream-editing)
   - [SSH & Remote Key Management](#ssh--remote-key-management)
   - [Archive & Data Transfer](#archive--data-transfer)
   - [Bash History, Job Control & Productive Shortcuts](#bash-history-job-control--productive-shortcuts)

---

## 1. WSL 2 Administration & Lifecycle

> **Note:** Run all `wsl` commands in Windows PowerShell or Windows Terminal (PowerShell prompt).

### Instance Lifecycle Management

| Task | Command | Description |
| :--- | :--- | :--- |
| **List Installed Distros** | `wsl --list --verbose` or `wsl -l -v` | Lists all installed distributions, their current execution state (`Running`/`Stopped`), and WSL version (`1` or `2`). |
| **List Available Distros** | `wsl --list --online` or `wsl -l -o` | Shows available Linux distributions available to install directly from Microsoft. |
| **Install New Distro** | `wsl --install -d <DistroName>` | Downloads and installs a specific distribution (e.g., `Ubuntu-24.04`, `Debian`). |
| **Launch Specific Distro** | `wsl -d <DistroName>` | Boots and opens an interactive shell in the specified distro. |
| **Launch as Specific User** | `wsl -d <DistroName> -u <Username>` | Drops directly into `root` or another user (useful for password recovery/fixing permissions). |
| **Run Ad-Hoc Command** | `wsl -d <DistroName> -- <command>` | Executes a command inside WSL without entering an interactive shell (e.g., `wsl -d Ubuntu -- uname -r`). |
| **Set Default Distro** | `wsl --set-default <DistroName>` or `wsl -s <DistroName>` | Sets the target distribution launched when running bare `wsl`. |
| **Terminate / Stop Distro** | `wsl --terminate <DistroName>` or `wsl -t <DistroName>` | Immediately stops and unloads a specific running instance, freeing its allocated memory. |
| **Shutdown WSL Engine** | `wsl --shutdown` | Completely terminates all running WSL instances and stops the lightweight VM host. |
| **Unregister / Delete Distro** | `wsl --unregister <DistroName>` | **Destructive**: Permanently deletes the distribution and removes its `.vhdx` virtual disk. |

---

### Export, Backup & Import Custom Distros

Exporting and importing allows creating snapshot backups, moving WSL instances across physical drives (e.g., to a secondary SSD), or cloning configured environments.

#### 1. Export (Backup Snapshot)
```powershell
# Shut down WSL to ensure clean disk state
wsl --shutdown

# Export distribution to a tar archive
wsl --export Ubuntu-24.04 D:\WSL_Backups\Ubuntu-24.04-backup.tar

# Or export compressed directly using PowerShell
wsl --export Ubuntu-24.04 - | gzip > D:\WSL_Backups\Ubuntu-24.04.tar.gz
```

#### 2. Import (Restore or Create a Duplicate Instance)
```powershell
# Syntax: wsl --import <NewDistroName> <InstallDirectory> <SourceTarPath> --version 2
wsl --import Ubuntu-Dev D:\WSL_Instances\Ubuntu-Dev D:\WSL_Backups\Ubuntu-24.04-backup.tar --version 2
```

#### 3. Configure Default User on Imported Distro
Imported distributions default to the `root` user. To set your default non-root user, configure `/etc/wsl.conf` inside the instance:
```bash
# Run inside the imported WSL distro:
sudo tee -a /etc/wsl.conf > /dev/null <<EOT
[user]
default=your_username
EOT
```
Then restart the instance in PowerShell:
```powershell
wsl -t Ubuntu-Dev
wsl -d Ubuntu-Dev
```

---

### Configuration & Resource Tuning

#### Global Host Settings (`C:\Users\<YourUser>\.wslconfig`)
Controls memory, CPU cores, and swap limits for all WSL 2 instances:
```ini
[wsl2]
memory=16GB           # Limit memory allocated to WSL 2 VM
processors=8          # Limit CPU logical cores
swap=8GB              # Allocate swap space
swapFile=C:\\temp\\wsl-swap.vhdx
localhostForwarding=true

[experimental]
autoMemoryReclaim=gradual   # Automatically reclaims cached memory back to Windows
sparseVhd=true             # Automatically compacts virtual disks
```

#### Per-Distribution Settings (`/etc/wsl.conf`)
Located inside each Linux filesystem to control systemd, automounts, and network integration:
```ini
[boot]
systemd=true          # Enables systemd service manager

[automount]
enabled=true
options="metadata,umask=22,fmask=11"
mountFsTab=true       # Process /etc/fstab automatically at boot

[network]
generateResolvConf=true

[interop]
enabled=true
appendWindowsPath=true
```

---

### Disk Maintenance & Compaction

WSL virtual disks (`ext4.vhdx`) grow dynamically but do not shrink automatically when files inside Linux are deleted.

```powershell
# 1. Terminate WSL
wsl --shutdown

# 2. Run Windows Diskpart
diskpart

# Inside Diskpart prompt:
select vdisk file="C:\Users\<YourUser>\AppData\Local\Packages\<DistroPackage>\LocalState\ext4.vhdx"
attach vdisk readonly
compact vdisk
detach vdisk
exit
```

---

### Windows-WSL Interoperability

```bash
# Access Windows files from WSL:
cd /mnt/c/Users/<YourUser>/Projects

# Access WSL filesystem from Windows Explorer:
# In Explorer address bar type: \\wsl$\<DistroName>\ or \\wsl.localhost\<DistroName>\

# Open current WSL directory in Windows File Explorer:
explorer.exe .

# Open current WSL directory in VS Code:
code .

# Pipe Linux terminal output directly into Windows Clipboard:
cat ~/.ssh/id_ed25519.pub | clip.exe
```

---

## 2. Essential Linux for Developers

Sorted by operational importance for daily software engineering and DevOps workflows.

---

### Storage & Network Drive Mounting (`/etc/fstab`)

Mounting internal storage, external volumes, and remote network shares (NFS/Samba/CIFS) persistently at boot.

#### 1. Disk & Block Device Discovery
```bash
# List all block devices, mount points, sizes, and filesystem types
lsblk -f

# List UUIDs for persistent mounting (UUIDs do not change across device reboots)
sudo blkid

# Check current filesystem disk usage in human-readable format
df -hT

# Measure directory disk footprint
du -sh /path/to/folder/*
```

#### 2. Manual Mounting
```bash
# Mount a local ext4 partition
sudo mkdir -p /mnt/data
sudo mount /dev/sdb1 /mnt/data

# Mount an SMB/CIFS (Samba / Windows Network Share)
sudo mkdir -p /mnt/share
sudo mount -t cifs //192.168.1.100/SharedFolder /mnt/share -o username=user,password=pass,uid=1000,gid=1000

# Mount an NFS share
sudo mkdir -p /mnt/nfs
sudo mount -t nfs 192.168.1.100:/volume1/nfs_share /mnt/nfs

# Unmount safely (lazy unmount if busy)
sudo umount /mnt/data
sudo umount -l /mnt/data  # Detach immediately and clean up references when free
```

#### 3. Permanent Auto-Mount via `/etc/fstab`
Add entries to `/etc/fstab` so volumes mount automatically during boot.

```bash
# Edit fstab
sudo nano /etc/fstab
```

**Standard Syntax:**
```text
<File_System_Or_UUID>    <Mount_Point>    <Type>    <Options>    <Dump>    <Pass>
```

**Examples:**

1. **Local Ext4 Partition (using UUID):**
   ```text
   UUID=3a1b2c3d-4e5f-6a7b-8c9d-0e1f2a3b4c5d  /mnt/data  ext4  defaults,noatime  0  2
   ```

2. **CIFS / Samba Network Share (Password protected):**
   ```text
   //192.168.1.100/SharedFolder  /mnt/share  cifs  credentials=/etc/samba/credentials,uid=1000,gid=1000,iocharset=utf8,_netdev,nofail  0  0
   ```
   *Create `/etc/samba/credentials` (`chmod 600`):*
   ```text
   username=myuser
   password=mypassword
   domain=WORKGROUP
   ```

3. **NFS Network Share:**
   ```text
   192.168.1.100:/volume1/nfs_share  /mnt/nfs  nfs  defaults,_netdev,nofail,timeo=14,intr  0  0
   ```
   *`_netdev` ensures mounting waits until network interfaces are up; `nofail` prevents boot failure if the network share is offline.*

4. **Verify fstab without rebooting (Crucial Step):**
   ```bash
   # Test-mount all entries in /etc/fstab
   sudo mount -a
   # If no error output, the configuration is valid.
   ```

---

### Process Management & Diagnostics

| Command | Usage | Description |
| :--- | :--- | :--- |
| `htop` / `btop` | `htop` | Interactive, colorized real-time viewer for CPU, memory, threads, and processes. |
| `ps` | `ps aux \| grep node` | Lists running processes with PID, user, CPU%, MEM%, and start command. |
| `pgrep` | `pgrep -l -f python` | Finds Process IDs (PID) matching a pattern. |
| `kill` | `kill <PID>` | Sends `SIGTERM` (15) to request graceful shutdown. |
| `kill -9` | `kill -9 <PID>` | Sends `SIGKILL` (9) to force termination immediately. |
| `pkill` / `killall` | `pkill -f "uvicorn"` | Kills all processes matching a given name or command line pattern. |
| `lsof` | `lsof -i :8080` | Identifies which process is listening on or using port 8080. |
| `fuser` | `fuser -k 3000/tcp` | Kills whichever process is holding TCP port 3000. |

---

### File Operations, Navigation & Search

| Command | Usage | Description |
| :--- | :--- | :--- |
| `find` | `find . -type f -name "*.log" -mtime +7 -delete` | Finds files recursively matching criteria and executes actions on them. |
| `rg` / `grep` | `rg "DATABASE_URL" --type env` | Searches file contents using regular expressions (`ripgrep` is ultra-fast). |
| `fd` | `fd -e py` | Modern, fast alternative to `find` for locating files/folders. |
| `rsync` | `rsync -avzP ./src/ user@server:/app/` | Synchronizes files locally or remotely with progress, compression, and resume support. |
| `tree` | `tree -L 2 -I 'node_modules\|.git'` | Displays directory hierarchy up to depth 2, excluding specified directories. |
| `ln` | `ln -s /path/to/target link_name` | Creates a symbolic link. |

---

### User Permissions & Security

```bash
# Octal Permissions: User / Group / Others (Read=4, Write=2, Execute=1)
chmod 755 script.sh          # rwxr-xr-x
chmod 600 id_rsa             # rw------- (Required for SSH private keys)
chmod -R 775 /var/www/html   # Recursive permissions change

# Ownership
sudo chown -R user:group /path/to/directory

# Run command as another user
sudo -u postgres psql

# View current user, UID, GID, and assigned groups
id
whoami
groups
```

---

### Systemd Services & Logs

```bash
# Manage system services
sudo systemctl start <service>
sudo systemctl stop <service>
sudo systemctl restart <service>
sudo systemctl reload <service>       # Reload configuration without restart
sudo systemctl status <service>
sudo systemctl enable --now <service> # Enable service at boot and start immediately

# View & follow service logs with Journalctl
journalctl -u <service> -f            # Real-time tail
journalctl -u <service> -n 100        # Last 100 log lines
journalctl -u <service> --since "1 hour ago"
journalctl -xe                        # Deep diagnostics on failed services
```

---

### Network Troubleshooting & Connectivity

| Command | Example | Purpose |
| :--- | :--- | :--- |
| `ip` | `ip a` / `ip route` | Shows network interfaces, IP addresses, and routing tables. |
| `ss` | `ss -tulpn` | Displays all listening TCP/UDP sockets with process and port information. |
| `curl` | `curl -Iv https://api.example.com` | Fetches headers, tests latency, and inspects HTTP response status. |
| `dig` / `nslookup` | `dig +short example.com` | Resolves DNS records and checks name server lookups. |
| `nc` (Netcat) | `nc -zv 10.0.0.1 5432` | Tests raw TCP connectivity to a specific host and port. |
| `ping` | `ping -c 4 1.1.1.1` | Tests ICMP round-trip latency and packet loss. |
| `traceroute` | `traceroute 8.8.8.8` | Traces route hops taken by packets across the network. |

---

## 3. Universal CLI & Bash Developer Productivity

---

### Text Processing & Stream Editing

```bash
# awk: Extract columns from formatted output
# Example: Print column 1 (user) and column 11 (command)
ps aux | awk '{print $1, $11}'

# sed: Stream editor for search and replace
# Replace all instances of 'localhost:3000' with 'api.prod.com' in-place
sed -i 's/localhost:3000/api.prod.com/g' config.json

# cut: Extract fields based on delimiter
echo "user:x:1000:1000:Developer:/home/user:/bin/bash" | cut -d: -f1,6

# sort & uniq: Count occurrences of unique log lines
cat access.log | awk '{print $1}' | sort | uniq -c | sort -nr | head -n 10

# jq: Parse, filter, and format JSON in terminal
curl -s https://api.github.com/repos/torvalds/linux | jq '{name: .name, stars: .stargazers_count}'

# xargs: Pass standard input as arguments to commands
find . -name "*.tmp" | xargs rm -f
```

---

### SSH & Remote Key Management

```bash
# Generate modern Ed25519 key pair with comment
ssh-keygen -t ed25519 -C "developer@machine"

# Copy public key to remote server for passwordless login
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@remote-host

# Forward local port 8080 to remote port 8080 through SSH tunnel
ssh -L 8080:localhost:8080 user@remote-host

# Maintain connection alive (put in ~/.ssh/config)
# Host *
#     ServerAliveInterval 60
#     ServerAliveCountMax 3
```

---

### Archive & Data Transfer

```bash
# Tar.gz Archive (Compress)
tar -czvf archive.tar.gz /path/to/folder

# Tar.gz Extract
tar -xzvf archive.tar.gz -C /target/path

# Extract .tar.xz
tar -xJvf archive.tar.xz

# Zip & Unzip
zip -r backup.zip folder/
unzip backup.zip -d target_dir/

# Download file with resume support
curl -C - -O https://example.com/largefile.iso
wget -c https://example.com/largefile.iso
```

---

### Bash History, Job Control & Productive Shortcuts

#### Navigation & Expansion Shortcuts
- `cd -` : Jump back to previous working directory.
- `cd` or `cd ~` : Return to home directory.
- `sudo !!` : Re-run the last command with `sudo`.
- `!$` : Expands to the last argument of the previous command (e.g., `mkdir /var/log/app && cd !$`).
- `!^` : Expands to the first argument of the previous command.
- `^old^new^` : Quick-fix typo in previous command and execute.

#### Terminal Keybindings (Emacs Mode)
- `Ctrl + R` : Incremental reverse history search.
- `Ctrl + A` : Move cursor to beginning of line.
- `Ctrl + E` : Move cursor to end of line.
- `Ctrl + U` : Cut/delete from cursor to beginning of line.
- `Ctrl + K` : Cut/delete from cursor to end of line.
- `Ctrl + W` : Delete the previous word.
- `Ctrl + L` : Clear screen (equivalent to `clear`).

#### Background Jobs & Execution Control
- `command &` : Run command in background.
- `Ctrl + Z` : Pause and send running foreground job to background.
- `bg` : Resume paused background job.
- `fg` : Bring most recent background job to foreground.
- `jobs -l` : List all active background jobs with PIDs.
- `nohup <command> > app.log 2>&1 &` : Run process immune to hangups even if terminal closes.
- `disown -h %1` : Prevent job 1 from closing when session ends.