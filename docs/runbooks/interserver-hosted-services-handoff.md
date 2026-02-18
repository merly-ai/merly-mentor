# InterServer Hosted Services Handoff (Vacation: 2026-02-21 to 2026-02-28)

## Scope and objective

This runbook is for coverage of Merly services on InterServer while the primary maintainer is away.

Use this as the single source of truth for:

- Access and emergency login
- Service health checks and restart procedures
- Routine monitoring while covering incidents
- Escalation and handoff notes

## 1) Access model and hosts

- There are 3 production Windows hosts.
- SSH is enabled on all three hosts and is now the preferred path for inspection.
- Use RDP only for UI-level repair, deep UI app checks, or when SSH cannot run required commands.
- Hosts:
  - Host A: `merly-mentor.ai` / `Administrator`
    - Observed hostname: `DESKTOP-J8LJTLP`
  - Host B: `cncf.merly-mentor.ai` / `Administrator`
    - Observed hostname: `WIN-3PR37DJS6T0`
  - Host C: `summaries.merly-mentor.ai` / `Administrator`
    - Observed hostname: `ubermerly-mento`

### Local SSH key and identity

- Local private key: `~/.ssh/merly-maint`
- Local public key: `~/.ssh/merly-maint.pub`
- Test key auth on all 3 hosts:

```bash
for h in merly-mentor.ai cncf.merly-mentor.ai summaries.merly-mentor.ai; do
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o PasswordAuthentication=no -o PubkeyAuthentication=yes \
    -i ~/.ssh/merly-maint Administrator@"$h" "hostname"
done
```

### First-time SSH setup on a fresh host

If SSH is not yet key-enabled on a host:

1. Connect with password once.
2. Add public key to:
   - `%ProgramData%\ssh\administrators_authorized_keys`
   - Optional: `%USERPROFILE%\.ssh\authorized_keys`
3. Run:
   - `icacls` clean-up for these files (remove `NT SERVICE\sshd`/`Everyone` from ACL if present).
   - Ensure `sshd` service exists and is `LocalSystem` with auto-start.
4. Test with the key-based command above.

> If your repository includes `merly-ssh-bootstrap.sh`, you can use it for one-shot host setup.

## 2) On-call contacts

- Backup maintainer: `___`
- Escalation backup: `___`
- Business-critical contact path: `interserver support ticket / billing`
- Credential storage:
  - Password manager entry path: `___`

If access details change, update this file before ending coverage.

## 3) Service inventory source (required each shift)

Use this source of truth first:

- `https://merlyserviceadmin.azurewebsites.net/Uptime`

Populate before beginning coverage:

- Current host -> service assignment:
  - Host A:
  - Host B:
  - Host C:
- Service process names:
  - Bridge:
  - UI:
  - WebPortal:
  - Daemon/runtime components:
  - Any scheduler or worker:
- Backup location / method:
  - `___`

### Notes

- Use MAS/Uptime first, then connect only to active hosts.
- If MAS is unavailable, treat all three hosts as potentially active and verify manually.

## 4) Instance configuration references

Each host runs Merly instances by `MerlyInstaller`, which writes per-instance settings to:

- `C:\Merly\.mentor\settings.json`

From SSH/RDC session on a host:

```powershell
Get-Content "C:\Merly\.mentor\settings.json" -Raw | ConvertFrom-Json | ConvertTo-Json -Depth 4
```

Use those values to identify Merly service process names and ports for service-level checks.

IIS should be checked via:

```powershell
Import-Module WebAdministration
Get-Website | Select-Object Name, State, ID, PhysicalPath, Bindings
```

## 5) Daily health check (5-15 minutes)

1. Open and record MAS/Uptime output.
2. Confirm host/service assignment from MAS.
3. Run host checks (SSH-first, RDP-only if needed).
4. Run functional smoke checks and record results.

### 5.1 Host OS health (SSH)

```powershell
Get-ComputerInfo | Select-Object CsName,OsName,WindowsVersion,OsArchitecture
Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize,FreePhysicalMemory
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
  Select-Object DeviceID,
    @{Name="UsedGB";Expression={[math]::Round(($_.Size - $_.FreeSpace)/1GB,2)},
    @{Name="FreeGB";Expression={[math]::Round($_.FreeSpace/1GB,2)}
Get-Process | Sort-Object CPU -Descending | Select-Object -First 15 Name,Id,CPU,WorkingSet
```

### 5.2 Merly service + IIS checks (SSH)

```powershell
# One host session
$s = Get-Content 'C:\Merly\.mentor\settings.json' -Raw | ConvertFrom-Json
[pscustomobject]@{
  Host = $env:COMPUTERNAME
  ServiceName = $s.service_name
  DaemonPort = $s.daemon_port
  MiddlewarePort = $s.middleware_port
  GuiPort = $s.gui_port
  Channel = $s.channel
  ServiceStatus = (Get-Service -Name $s.service_name -ErrorAction SilentlyContinue).Status
  ServiceStartType = (Get-Service -Name $s.service_name -ErrorAction SilentlyContinue).StartType
}
Import-Module WebAdministration
Get-Website | Select-Object Name, State, ID, PhysicalPath, Bindings
```

If a service is stopped:

1. Confirm startup type and recovery policy in `services.msc`.
2. Capture relevant logs/events before restart.
3. Restart only the failing service: `Restart-Service -Name "<ServiceName>"`.

### 5.3 SSHd service health checks (important)

```powershell
Get-Service sshd | Select-Object Name,Status,StartType,StartName
Get-CimInstance Win32_Service -Filter "Name='sshd'" | Select-Object Name,State,Status,StartName,ProcessId
Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue | Select-Object LocalAddress,OwningProcess
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Service Control Manager'; Id=7000,7001,7004,7022,7031,7034; StartTime=(Get-Date).AddHours(-6)} |
  Select-Object TimeCreated,Id,LevelDisplayName,Message
```

### 5.4 Event and app logs

```powershell
Get-WinEvent -LogName Application -MaxEvents 200 | Where-Object { $_.LevelDisplayName -in @("Error","Critical") } |
  Select-Object TimeCreated,Id,LevelDisplayName,ProviderName,Message
Get-WinEvent -LogName System -MaxEvents 200 | Where-Object { $_.LevelDisplayName -in @("Error","Critical") } |
  Select-Object TimeCreated,Id,LevelDisplayName,ProviderName,Message
```

Also open `eventvwr.msc` for interactive checks and app-specific log locations.

### 5.5 Functional smoke checks (from laptop/monitor host)

```bash
curl -I https://<public-domain-or-ip>/<bridge-health-endpoint>
curl -I https://<public-domain-or-ip>/
curl -I https://<webportal-domain-or-ip>/swagger
```

Use the production endpoints from your route map and record status over 1-2 minutes before/after any restart.

## 6) Mass SSH validation on all 3 hosts

Use this checklist every handoff:

```bash
for h in merly-mentor.ai cncf.merly-mentor.ai summaries.merly-mentor.ai; do
  ssh -o BatchMode=yes -o PasswordAuthentication=no -o PubkeyAuthentication=yes \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i ~/.ssh/merly-maint Administrator@"$h" \
    "hostname; Get-Service sshd; Get-Service | Where-Object { $_.Name -like 'Merly*' }"
done
```

## 7) Incident handling playbooks

### A) Service not reachable / restart loop

1. In SSH or RDP, capture recent errors (`Application`, `System`, `Service Control Manager`).
2. Confirm host disk and process health first.
3. Restart only the failing service.
4. Re-check service status and smoke checks.
5. If unstable after 2-3 cycles or recurring after 15 minutes:
   - capture timestamped evidence
   - escalate to on-call owner.

### B) 5xx/API errors after deployment

1. Re-check MAS/Uptime for host/service ownership and expected version.
2. Restart dependent frontend/proxy service first, then backend service.
3. Execute one end-to-end smoke sequence (login, create repo/job if available).
4. If reproducible and repeatable, rollback to last known good artifact.

### C) High resource pressure

1. Identify culprit with `Get-Process` ranking CPU/memory.
2. Stop optional workers first.
3. If sustained growth continues, escalate capacity action.

### D) SSHd failing to stay up

When sshd is not starting or repeatedly exits:

1. Check host key ACLs and service config:

```powershell
icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r /remove:g "NT SERVICE\sshd" "Everyone" "BUILTIN\Users" "NT AUTHORITY\Authenticated Users"
icacls C:\ProgramData\ssh\administrators_authorized_keys /grant "NT AUTHORITY\SYSTEM:(F)" "BUILTIN\Administrators:(F)"
Get-Item C:\ProgramData\ssh\ssh_host_rsa_key,C:\ProgramData\ssh\ssh_host_ecdsa_key,C:\ProgramData\ssh\ssh_host_ed25519_key | ForEach-Object {
  icacls $_.FullName /inheritance:r /grant "NT AUTHORITY\SYSTEM:(F)" "BUILTIN\Administrators:(F)"
}
& "$env:WINDIR\System32\OpenSSH\ssh-keygen.exe" -A
```

2. Restart and verify:

```powershell
Restart-Service sshd
Get-Service sshd | Select-Object Name,Status,StartType
```

3. Re-run the mass SSH validation in section 6.

## 8) Backup and data safeguards

- Verify backup schedule completion within 24 hours.
- Confirm these items exist:
  - database backup (or managed DB backup evidence)
  - runtime config snapshots
  - secrets/config copies
- If backups are missing/unknown, avoid major restarts until confirmed.
- Avoid destructive cleanup commands unless approved by primary owner.

## 9) Escalation criteria

Escalate immediately if any condition is true:

- Two or more production services fail at once.
- Disk usage stays above 85% and trending up.
- Repeated restart loops with no recovery.
- Auth/license outages affecting end users.
- Service or certificate issue unresolved for >30 minutes.

## 10) Post-coverage checklist

Before passing control:

- Log each incident with start time, actions, commands, and outcome.
- Verify all MAS/Uptime services are green.
- Confirm placeholders in this handoff are fully filled.
- Send a short handoff summary to the primary maintainer.

## 11) Current verified SSH baseline (2026-02-18)

- `merly-mentor.ai` -> key auth works, `sshd` reachable.
- `cncf.merly-mentor.ai` -> key auth works, `sshd` reachable.
- `summaries.merly-mentor.ai` -> key auth works, `sshd` reachable.

Re-run and log these checks at each coverage shift.

## 12) References

- MAS uptime: `https://merlyserviceadmin.azurewebsites.net/Uptime`
- `./scripts/thread-runtime.sh` for local reproducible checks and channel promotion.
- `docs/process/thread-runtime-and-delivery.md`
- `docs/process/daemon-test-to-pre-release.md`
- `docs/process/e2e-local-validation.md`
- `docs/process/change-implementation-review-deploy.md`
- `docs/process/agent-codex-instructions.md`
- `docs/repositories/installer-and-release.md`
- `docs/repositories/webportal.md`
