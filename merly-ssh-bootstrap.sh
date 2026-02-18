#!/usr/bin/env bash
set -euo pipefail

HOSTS=(
  "merly-mentor.ai"
  "cncf.merly-mentor.ai"
  "summaries.merly-mentor.ai"
)

USER_NAME="Administrator"
KEY_PATH="${HOME}/.ssh/merly-maint"
DIAG_MINUTES=180
DISABLE_PASSWORD_AUTH=0
LOG_ROOT="./merly-ssh-bootstrap-logs"

usage() {
  cat <<'USAGE'
Usage: merly-ssh-bootstrap.sh [options] [host1 host2 ...]

Options:
  --user USER             Remote user (default: Administrator)
  --key-path PATH         Local private key path (default: ~/.ssh/merly-maint)
  --diag-minutes N        Diagnostic window in minutes (default: 180)
  --disable-password-auth  Do not prompt for password if key auth fails
  --log-root PATH         Log directory root (default: ./merly-ssh-bootstrap-logs)
  --help                  Show this help

If no hosts are provided, the defaults are:
  merly-mentor.ai
  cncf.merly-mentor.ai
  summaries.merly-mentor.ai
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      USER_NAME="$2"
      shift 2
      ;;
    --key-path)
      KEY_PATH="$2"
      shift 2
      ;;
    --diag-minutes)
      DIAG_MINUTES="$2"
      shift 2
      ;;
    --disable-password-auth)
      DISABLE_PASSWORD_AUTH=1
      shift
      ;;
    --log-root)
      LOG_ROOT="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      HOSTS=("$@")
      break
      ;;
  esac
done

if ! command -v ssh >/dev/null 2>&1; then
  echo "ssh binary not found. Install OpenSSH client and retry." >&2
  exit 1
fi

if ! command -v iconv >/dev/null 2>&1 || ! command -v base64 >/dev/null 2>&1; then
  echo "iconv and base64 must be installed. Install Command Line Tools and retry." >&2
  exit 1
fi

ssh_key_dir="$(dirname "$KEY_PATH")"
mkdir -p "$ssh_key_dir"

RUN_DIR="${LOG_ROOT}/$(date +%Y%m%d_%H%M%S)"
HOST_LOG_DIR="${RUN_DIR}/hosts"
mkdir -p "$HOST_LOG_DIR"
RUN_LOG="${RUN_DIR}/run.log"

touch "$RUN_LOG"
LOG() {
  local level="$1"
  local host="$2"
  local msg="$3"
  echo "[$(date -Iseconds)] [${host}] [${level}] ${msg}" | tee -a "$RUN_LOG"
}

escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

run_ssh() {
  local out_file="$1"
  local host="$2"
  shift 2
  set +e
  ssh "$@" "$host" >"$out_file" 2>&1
  local rc=$?
  set -e
  return "$rc"
}

if [[ ! -f "$KEY_PATH" ]]; then
  LOG "INFO" "local" "No private key found at $KEY_PATH. Creating RSA 4096 key."
  ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -C "merly-maint" -N ""
else
  LOG "INFO" "local" "Reusing existing key at $KEY_PATH."
fi

if [[ ! -f "${KEY_PATH}.pub" ]]; then
  LOG "INFO" "local" "Public key missing; generating from private key."
  ssh-keygen -y -f "$KEY_PATH" > "${KEY_PATH}.pub"
fi

PUBLIC_KEY="$(cat "${KEY_PATH}.pub")"
if [[ -z "${PUBLIC_KEY//[[:space:]]/}" ]]; then
  echo "Public key file is empty: ${KEY_PATH}.pub" >&2
  exit 1
fi

PUBLIC_KEY_B64="$(printf '%s' "$PUBLIC_KEY" | base64 | tr -d '\n')"
PASSWORD_AUTH_VALUE="yes"
if [[ "$DISABLE_PASSWORD_AUTH" -eq 1 ]]; then
  PASSWORD_AUTH_VALUE="no"
fi

REMOTE_SETUP_SCRIPT=$(cat <<PS1
\$ErrorActionPreference = 'Stop'
\$ProgressPreference = 'SilentlyContinue'

\$publicKey = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$PUBLIC_KEY_B64')).Trim()
\$passwordAuthValue = '$PASSWORD_AUTH_VALUE'

\$result = [ordered]@{
    Hostname = \$env:COMPUTERNAME
    Steps = @()
    Errors = @()
}

try {
    \$result.Steps += 'Preparing authorized_keys'
    \$authorizedTargets = @(
        Join-Path \$env:ProgramData 'ssh\\administrators_authorized_keys',
        (Join-Path \$env:USERPROFILE '.ssh\\authorized_keys')
    )

    foreach (\$path in \$authorizedTargets) {
        \$dir = Split-Path \$path -Parent
        New-Item -ItemType Directory -Path \$dir -Force | Out-Null
        New-Item -ItemType File -Path \$path -Force | Out-Null

        \$current = Get-Content \$path -Raw -ErrorAction SilentlyContinue
        if (-not \$current -or (\$current -notmatch [regex]::Escape(\$publicKey))) {
            Add-Content -Path \$path -Value \$publicKey
            \$result.Steps += "Added key to \$path"
        } else {
            \$result.Steps += "Key already present in \$path"
        }

        if (\$path -like '*administrators_authorized_keys') {
            icacls \$dir /inheritance:r /grant "SYSTEM:(OI)(CI)F" "BUILTIN\\Administrators:(OI)(CI)F" | Out-Null
            icacls \$path /inheritance:r /grant "SYSTEM:F" "BUILTIN\\Administrators:F" | Out-Null
        }
        else {
            \$user = \$env:USERNAME
            icacls \$dir /inheritance:r /grant "\${user}:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "BUILTIN\\Administrators:(OI)(CI)F" | Out-Null
            icacls \$path /inheritance:r /grant "\${user}:F" "SYSTEM:F" "BUILTIN\\Administrators:F" | Out-Null
        }
    }

    \$cfgPath = Join-Path \$env:ProgramData 'ssh\\sshd_config'
    \$cfg = @"
Port 22
ListenAddress 0.0.0.0
ListenAddress ::
PubkeyAuthentication yes
PasswordAuthentication \$passwordAuthValue
AuthorizedKeysFile .ssh/authorized_keys C:/ProgramData/ssh/administrators_authorized_keys
Subsystem powershell C:/Windows/System32/OpenSSH/powershell.exe
"@
    Set-Content -Path \$cfgPath -Value \$cfg -NoNewline -Encoding Ascii

    \$keygen = Join-Path \$env:windir 'System32\\OpenSSH\\ssh-keygen.exe'
    if (Test-Path \$keygen) {
        & \$keygen -A | Out-Null
    }

    \$cap = Get-WindowsCapability -Online | Where-Object { \$_.Name -like 'OpenSSH.Server*' } | Select-Object -First 1
    if (\$null -eq \$cap) { throw 'No OpenSSH.Server capability is available on this host.' }
    if (\$cap.State -ne 'Installed') {
        Add-WindowsCapability -Online -Name \$cap.Name | Out-Null
    }

    \$maxWaitSeconds = 30
    \$elapsed = 0
    while (\$elapsed -lt \$maxWaitSeconds -and -not (Get-Service sshd -ErrorAction SilentlyContinue)) {
        Start-Sleep -Seconds 1
        \$elapsed++
    }

    \$service = Get-Service sshd -ErrorAction SilentlyContinue
    if (-not \$service) { throw 'sshd service is not installed or registered on this host.' }
    Set-Service sshd -StartupType Automatic
    try {
        Restart-Service sshd -Force
    } catch {
        Start-Service sshd
    }

    \$rule = Get-NetFirewallRule -Name 'OpenSSH-22' -ErrorAction SilentlyContinue
    if (-not \$rule) {
        New-NetFirewallRule -Name 'OpenSSH-22' -DisplayName 'OpenSSH SSH Server (sshd)' -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow -Profile Any | Out-Null
    } else {
        Set-NetFirewallRule -Name 'OpenSSH-22' -Enabled True | Out-Null
    }

    \$result.Steps += "Configured service and firewall; status=\$((Get-Service sshd).Status)"
    \$result.Steps += "Config file: \$cfgPath"
}
catch {
    \$result.Errors += \$_.Exception.Message
}

\$result | ConvertTo-Json -Depth 6
PS1
)

REMOTE_DIAG_SCRIPT=$(cat <<PS1
\$ErrorActionPreference = 'Continue'
\$ProgressPreference = 'SilentlyContinue'

\$diag = [ordered]@{
    Timestamp = (Get-Date).ToString('o')
    Hostname = \$env:COMPUTERNAME
    OS = (Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)
    SshdService = \$null
    SshdConfigPath = \$null
    SshdConfig = \$null
    FirewallRule = \$null
    IisSites = @()
    MerlyLikeServices = @()
    WinEventOperational = @()
    WinEventAdmin = @()
    Errors = @()
}

try {
    \$diag.SshdService = Get-Service sshd -ErrorAction Stop | Select-Object Status,Name,DisplayName,StartType
} catch {
    \$diag.Errors += "sshd: \$($_.Exception.Message)"
}

try {
    \$diag.SshdConfigPath = Join-Path \$env:ProgramData 'ssh\\sshd_config'
    \$diag.SshdConfig = Get-Content \$diag.SshdConfigPath -Raw
} catch {
    \$diag.Errors += "sshd_config: \$($_.Exception.Message)"
}

try {
    \$diag.FirewallRule = Get-NetFirewallRule -Name 'OpenSSH-22' -ErrorAction Stop |
        Select-Object Name,Enabled,Direction,Action,Profile
} catch {
    \$diag.Errors += "Firewall rule: \$($_.Exception.Message)"
}

try {
    Import-Module WebAdministration -ErrorAction Stop
    \$diag.IisSites = Get-Website | Select-Object name,state,id
} catch {
    \$diag.Errors += "IIS: \$($_.Exception.Message)"
}

try {
    \$diag.MerlyLikeServices = Get-Service |
        Where-Object { \$_.Name -like '*merly*' -or \$_.DisplayName -like '*merly*' } |
        Select-Object Name,DisplayName,Status,StartType
} catch {
    \$diag.Errors += "Services scan: \$($_.Exception.Message)"
}

\$start = (Get-Date).AddMinutes(-$DIAG_MINUTES)
try {
    \$diag.WinEventOperational = Get-WinEvent -FilterHashtable @{ LogName='OpenSSH/Operational'; StartTime=\$start } -ErrorAction Stop |
        Sort-Object TimeCreated -Descending | Select-Object -First 40 TimeCreated,Id,LevelDisplayName,Message
} catch {
    \$diag.Errors += "OpenSSH/Operational: \$($_.Exception.Message)"
}

try {
    \$diag.WinEventAdmin = Get-WinEvent -FilterHashtable @{ LogName='OpenSSH/Admin'; StartTime=\$start } -ErrorAction Stop |
        Sort-Object TimeCreated -Descending | Select-Object -First 40 TimeCreated,Id,LevelDisplayName,Message
} catch {
    \$diag.Errors += "OpenSSH/Admin: \$($_.Exception.Message)"
}

\$diag | ConvertTo-Json -Depth 10
PS1
)

REMOTE_SETUP_CMD="$(printf '%s' "$REMOTE_SETUP_SCRIPT" | iconv -t UTF-16LE | base64 | tr -d '\n')"
REMOTE_DIAG_CMD="$(printf '%s' "$REMOTE_DIAG_SCRIPT" | iconv -t UTF-16LE | base64 | tr -d '\n')"
REMOTE_SETUP_REMOTE="powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand ${REMOTE_SETUP_CMD}"
REMOTE_DIAG_REMOTE="powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand ${REMOTE_DIAG_CMD}"

run_start=$(date -Iseconds)
REPORT_ENTRIES=()

for targetHost in "${HOSTS[@]}"; do
  targetSafe="$(echo "$targetHost" | tr -c 'A-Za-z0-9_.-' '_')"
  hostLog="${HOST_LOG_DIR}/${targetSafe}.log"
  diagLog="${HOST_LOG_DIR}/${targetSafe}-diagnostics.json"
  touch "$hostLog"

  LOG "INFO" "$targetHost" "Starting bootstrap."

  target="${USER_NAME}@${targetHost}"

  keyCheckOutput="$(mktemp)"
  set +e
  run_ssh "$keyCheckOutput" "$target" \
        -o BatchMode=yes \
        -o PasswordAuthentication=no \
        -o PubkeyAuthentication=yes \
        -o PreferredAuthentications=publickey \
        -o NumberOfPasswordPrompts=0 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=8 \
        -i "$KEY_PATH" \
        "hostname"
  keyCheckRC=$?
  set -e
  cat "$keyCheckOutput" >> "$hostLog"
  keyHostname=$(sed -n '1p' "$keyCheckOutput" | tr -d '\r')
  rm -f "$keyCheckOutput"

  keyAuthWorked=0
  setupExit=0
  verifyOutput="$(mktemp)"
  verifyRC=1
  setupOutput="Key auth already succeeds; bootstrap skipped."

  if [[ "$keyCheckRC" -eq 0 ]]; then
    keyAuthWorked=1
    verifyRC=0
    setupOutput="Skipped password setup; key auth already worked."
    LOG "SUCCESS" "$targetHost" "Key-only auth already works (hostname: ${keyHostname})."
  else
    LOG "WARN" "$targetHost" "Key auth check failed (code ${keyCheckRC}), attempting password bootstrap."
    if [[ "$DISABLE_PASSWORD_AUTH" -eq 1 ]]; then
      setupExit=1
      setupOutput="Disabled password auth and key auth failed for this host."
      LOG "ERROR" "$targetHost" "Password auth disabled. Skipping bootstrap changes."
    else
      bootstrapOutput="$(mktemp)"
      set +e
      run_ssh "$bootstrapOutput" "$target" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o PreferredAuthentications=password \
        -o PubkeyAuthentication=no \
        -o PasswordAuthentication=yes \
        -o KbdInteractiveAuthentication=no \
        -o ConnectTimeout=10 \
        "$REMOTE_SETUP_REMOTE"
      setupExit=$?
      set -e
      cat "$bootstrapOutput" >> "$hostLog"
      setupOutput="$(sed -n '1,120p' "$bootstrapOutput")"
      rm -f "$bootstrapOutput"
      if [[ "$setupExit" -ne 0 ]]; then
        LOG "ERROR" "$targetHost" "Setup command failed with code ${setupExit}."
      else
        LOG "INFO" "$targetHost" "Setup command completed. Verifying key-only auth."
        if run_ssh "$verifyOutput" "$target" \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o PasswordAuthentication=no \
          -o PubkeyAuthentication=yes \
          -o PreferredAuthentications=publickey \
          -o NumberOfPasswordPrompts=0 \
          -o BatchMode=yes \
          -o ConnectTimeout=10 \
          -i "$KEY_PATH" \
          "hostname"; then
          keyHostname="$(sed -n '1p' "$verifyOutput" | tr -d '\r')"
          LOG "SUCCESS" "$targetHost" "Key-only auth verified (hostname: ${keyHostname})."
          verifyRC=0
        else
          verifyRC=$?
          LOG "WARN" "$targetHost" "Key-only verification failed after bootstrap (code ${verifyRC})."
          keyHostname="$(sed -n '1p' "$verifyOutput" | tr -d '\r')"
        fi
      fi
    fi
  fi

  if [[ "$keyAuthWorked" -eq 1 || "$setupExit" -eq 0 || "$verifyRC" -eq 0 ]]; then
    if run_ssh "$diagLog" "$target" \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o PasswordAuthentication=no \
      -o PubkeyAuthentication=yes \
      -o PreferredAuthentications=publickey \
      -o NumberOfPasswordPrompts=0 \
      -o BatchMode=yes \
      -o ConnectTimeout=10 \
      -i "$KEY_PATH" \
      "$REMOTE_DIAG_REMOTE"; then
      LOG "INFO" "$targetHost" "Diagnostics collected: $diagLog"
    else
      LogLine="Diagnostics collection returned non-zero for $targetHost. Check run and auth state."
      LOG "WARN" "$targetHost" "$LogLine"
    fi
  else
    LOG "WARN" "$targetHost" "Skipping diagnostics (no key-based connectivity)."
  fi

  rm -f "$verifyOutput"

  if [[ "$keyAuthWorked" -eq 1 ]]; then
    access="Key auth success"
  elif [[ "$verifyRC" -eq 0 ]]; then
    access="Key auth success"
  else
    access="Key auth failed"
  fi

  REPORT_ENTRIES+=("{\"host\":\"$(escape_json "$targetHost")\",\"target\":\"$(escape_json "$target")\",\"setupExitCode\":$setupExit,\"keyCheckExitCode\":$keyCheckRC,\"verifyExitCode\":$verifyRC,\"keyAuthWorked\":$(if [[ "$keyAuthWorked" -eq 1 ]]; then echo true; else echo false; fi),\"hostname\":\"$(escape_json "$keyHostname")\",\"keyAuth\":$(if [[ \"$keyAuthWorked\" -eq 1 || \"$verifyRC\" -eq 0 ]]; then echo true; else echo false; fi),\"hostLog\":\"$(escape_json "$hostLog")\",\"diagnosticLog\":\"$(escape_json "$diagLog")\",\"access\":\"$(escape_json "$access")\"}")
done

runReport="${RUN_DIR}/merly-ssh-bootstrap-report.json"
{
  echo "{"
  echo "  \"generatedAt\": \"$(escape_json "$run_start")\","
  echo "  \"runDir\": \"$(escape_json "$RUN_DIR")\","
  echo "  \"diagMinutes\": $DIAG_MINUTES,"
  echo "  \"disablePasswordAuth\": $([ "$DISABLE_PASSWORD_AUTH" -eq 1 ] && echo true || echo false),"
  echo "  \"hosts\": ["
  for i in "${!REPORT_ENTRIES[@]}"; do
    if [[ "$i" -lt "$((${#REPORT_ENTRIES[@]} - 1))" ]]; then
      echo "    ${REPORT_ENTRIES[$i]},"
    else
      echo "    ${REPORT_ENTRIES[$i]}"
    fi
  done
  echo "  ]"
  echo "}"
} > "$runReport"

cp "$runReport" "./merly-ssh-bootstrap-report.json"
LOG "INFO" "local" "Run report: $runReport"
LOG "INFO" "local" "Run log: $RUN_LOG"
echo "Done. Logs available in: $RUN_DIR"
