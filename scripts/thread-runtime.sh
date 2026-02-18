#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_COMPOSE="${ROOT_DIR}/mentor-tests/infrastructure/docker-compose.yml"
TEST_DIR="${ROOT_DIR}/mentor-tests"
PUSH_CHANNEL_SCRIPT="${ROOT_DIR}/Merly.Installer/push-channel.py"
DIAG_BASE_DIR="${THREAD_RUNTIME_DIAG_DIR:-${ROOT_DIR}/.thread-runtime-diagnostics}"
DIAG_SESSION_ID="${THREAD_RUNTIME_DIAG_SESSION_ID:-thread-$(date '+%Y%m%d-%H%M%S')}"
DIAG_SESSION_DIR="${DIAG_BASE_DIR}/${DIAG_SESSION_ID}"
DIAG_AUTO="${THREAD_RUNTIME_DIAGNOSTICS:-1}"
DIAG_AUTO_ON_ERROR="${THREAD_RUNTIME_DIAGNOSTICS_ON_ERROR:-1}"
DIAG_CONTAINER_LIMIT="${THREAD_RUNTIME_DIAGNOSTICS_CONTAINER_LIMIT:-10}"
LAST_DIAGNOSTICS_PATH=""
THREAD_RUNTIME_ARGS=("$@")

sanitize_segment() {
  local input="$1"
  printf '%s' "$input" | tr '[:upper:]' '[:lower:]' | sed 's#[^a-z0-9._-]#_#g'
}

init_diagnostics() {
  mkdir -p "$DIAG_SESSION_DIR"
}

log_diag() {
  local message="$1"
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$message" >> "${DIAG_SESSION_DIR}/events.log"
}

run_with_diag() {
  local label="$1"
  local safe_label
  safe_label="$(sanitize_segment "$label")"
  shift
  init_diagnostics
  mkdir -p "${DIAG_SESSION_DIR}/commands"
  local logfile="${DIAG_SESSION_DIR}/commands/${safe_label}.log"
  local command_start_ts
  local command_end_ts
  command_start_ts="$(date '+%s')"
  log "Running ($label): $*"
  log_diag "command_start label=$label cmd=$*"
  (
    "$@"
  ) 2>&1 | tee "$logfile"
  local rc="${PIPESTATUS[0]}"
  command_end_ts="$(date '+%s')"
  local elapsed=$((command_end_ts - command_start_ts))
  log_diag "command_end label=$label rc=$rc duration_seconds=$elapsed log=$logfile"
  return "$rc"
}

run_with_diag_in_dir() {
  local label="$1"
  local workdir="$2"
  local safe_label
  safe_label="$(sanitize_segment "$label")"
  shift 2
  init_diagnostics
  mkdir -p "${DIAG_SESSION_DIR}/commands"
  local logfile="${DIAG_SESSION_DIR}/commands/${safe_label}.log"
  log "Running in ${workdir} ($label): $*"
  log_diag "command_start label=$label workdir=$workdir cmd=$*"
  local command_start_ts
  local command_end_ts
  command_start_ts="$(date '+%s')"
  (
    cd "$workdir"
    "$@"
  ) 2>&1 | tee "$logfile"
  local rc="${PIPESTATUS[0]}"
  command_end_ts="$(date '+%s')"
  local elapsed=$((command_end_ts - command_start_ts))
  log_diag "command_end label=$label rc=$rc duration_seconds=$elapsed log=$logfile"
  return "$rc"
}

collect_runtime_diagnostics() {
  local reason="${1:-manual}"
  local exit_code="${2:-<unknown>}"
  local out_dir="${DIAG_SESSION_DIR}/runtime-${reason}-$(date '+%Y%m%d-%H%M%S')"
  LAST_DIAGNOSTICS_PATH="$out_dir"
  local ts
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  mkdir -p "$out_dir/commands" "$out_dir/containers"

  log "Collecting diagnostics to $out_dir"
  {
    echo "Thread runtime diagnostics"
    echo "timestamp=${ts}"
    echo "reason=${reason}"
    echo "root_dir=${ROOT_DIR}"
    echo "diag_session=${DIAG_SESSION_DIR}"
    echo "command=$0 $*"
    echo "MM_KEY=${MM_KEY:-<unset>}"
    echo "CI_TEST_USER_NAME=${CI_TEST_USER_NAME:-<unset>}"
    echo "CI_TEST_USER_EMAIL=${CI_TEST_USER_EMAIL:-<unset>}"
    echo "BRIDGE_TEST_EMAIL=${BRIDGE_TEST_EMAIL:-<unset>}"
    echo "BRIDGE_TEST_URL=${BRIDGE_TEST_URL:-<unset>}"
    echo "BRIDGE_TEST_PATTERN=${BRIDGE_TEST_PATTERN:-<unset>}"
    echo "BRIDGE_TEST_API_VERSION=${BRIDGE_TEST_API_VERSION:-<unset>}"
    echo "BRIDGE_TEST_RESET_STATE=${BRIDGE_TEST_RESET_STATE:-<unset>}"
    echo "THREAD_RUNTIME_DIAG_DIR=${THREAD_RUNTIME_DIAG_DIR:-<unset>}"
    echo "THREAD_RUNTIME_DIAGNOSTICS=${THREAD_RUNTIME_DIAGNOSTICS:-<unset>}"
    echo "THREAD_RUNTIME_DIAGNOSTICS_ON_ERROR=${THREAD_RUNTIME_DIAGNOSTICS_ON_ERROR:-<unset>}"
    echo "THREAD_RUNTIME_DIAGNOSTICS_CONTAINER_LIMIT=${THREAD_RUNTIME_DIAGNOSTICS_CONTAINER_LIMIT:-<unset>}"
    echo "command_exit_code=${exit_code}"
  } > "$out_dir/context.txt"

  if command -v git >/dev/null 2>&1; then
    {
      git -C "$ROOT_DIR" status --short
      git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD
      git -C "$ROOT_DIR" log -1 --oneline
    } > "$out_dir/git.txt" 2>&1 || true
  fi

  if command -v docker >/dev/null 2>&1; then
    {
      docker --version
      docker compose version
      uname -a
      free -h
      df -h "${ROOT_DIR}"
      ulimit -a
      docker compose -f "$INFRA_COMPOSE" ps -a
      if docker compose -f "$INFRA_COMPOSE" ps -a -q >/dev/null 2>&1; then
        docker compose -f "$INFRA_COMPOSE" images
      fi
      if [[ -f "$INFRA_COMPOSE" ]]; then
        docker compose -f "$INFRA_COMPOSE" config --services > "$out_dir/compose-services.txt" 2>&1
      fi
      docker ps --format '{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}'
      docker compose -f "$INFRA_COMPOSE" ps -a
      docker compose -f "$INFRA_COMPOSE" logs --no-color --timestamps 2>&1 || true
      docker compose -f "$INFRA_COMPOSE" config > "$out_dir/compose-config.yaml" 2>&1 || true
    } > "$out_dir/docker-summary.txt" 2>&1 || true
  fi

  if command -v docker >/dev/null 2>&1; then
    local -a cids=()
    local name
    local safe_name
    mapfile -t cids < <(docker compose -f "$INFRA_COMPOSE" ps -a -q 2>/dev/null || true)
    if (( ${#cids[@]} == 0 )); then
      mapfile -t cids < <(docker ps -a --format '{{.ID}}' | head -n "$DIAG_CONTAINER_LIMIT" || true)
    fi
    for cid in "${cids[@]}"; do
      [[ -z "$cid" ]] && continue
      {
        name="$(docker inspect -f '{{.Name}}' "$cid" 2>/dev/null | sed 's#^/##')"
        safe_name="$(sanitize_segment "${name:-$cid}")"
        docker inspect "$cid" > "$out_dir/containers/${safe_name}.json" 2>&1 || true
        docker logs "$cid" > "$out_dir/containers/${safe_name}.log" 2>&1 || true
      } || true
    done
  fi

  if [[ -d "$TEST_DIR/playwright-report" ]]; then
    mkdir -p "$out_dir/mentor-tests"
    cp -R "$TEST_DIR/playwright-report" "$out_dir/mentor-tests/" || true
  fi
  if [[ -d "$TEST_DIR/test-results" ]]; then
    mkdir -p "$out_dir/mentor-tests"
    cp -R "$TEST_DIR/test-results" "$out_dir/mentor-tests/" || true
  fi

  if [[ -d "$ROOT_DIR/mentor-tests/.bridge-swagger-artifacts" ]]; then
    mkdir -p "$out_dir/mentor-tests"
    cp -R "$ROOT_DIR/mentor-tests/.bridge-swagger-artifacts" "$out_dir/mentor-tests/" || true
  elif [[ -d "${DIAG_SESSION_DIR}/bridge-swagger" ]]; then
    mkdir -p "$out_dir/mentor-tests"
    cp -R "${DIAG_SESSION_DIR}/bridge-swagger" "$out_dir/mentor-tests/" || true
  fi

  if [[ -f "$out_dir/docker-summary.txt" ]]; then
    tail -n 200 "$out_dir/docker-summary.txt" > "$out_dir/docker-summary-tail.txt" || true
  fi

  {
    echo "command_session_args=${THREAD_RUNTIME_ARGS[*]:-<none>}"
    echo "command_exit_code=${exit_code}"
  } > "$out_dir/summary.txt"
}

log() {
  echo "[$(date '+%H:%M:%S')] $*"
}

diag_trap() {
  local rc=$?
  if [[ "$DIAG_AUTO_ON_ERROR" == "1" ]]; then
    collect_runtime_diagnostics "error" "$rc"
    log "Diagnostics written to: ${LAST_DIAGNOSTICS_PATH}"
  fi
  log "command failed with exit code ${rc}"
  return "$rc"
}

if [[ "$DIAG_AUTO" == "1" ]]; then
  trap diag_trap ERR
fi

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command '$1' is not installed or not on PATH" >&2
    exit 1
  fi
}

usage() {
  cat <<'EOF'
Usage:
  ./scripts/thread-runtime.sh <command> [options]

Commands:
  check
    Verify local CLI tools required for local thread workflows.

  fetch-mm-key [--username QA Test User] [--email qa-test@merly.ai] [--endpoint https://merlyserviceadmin.azurewebsites.net]
    Fetch a valid MM_KEY from MAS TrialRegistration/GetOrCreateKey using CI defaults or provided identity.

  run-local-tests-with-public-key [--username QA Test User] [--email qa-test@merly.ai] [--remote-endpoint https://merlyserviceadmin.azurewebsites.net] [--local-mas-endpoint http://localhost:5002] [--who qa-reset-bot] [--run-e2e] [--run-bridge-swagger] [--no-reset] [--no-e2e] [--no-bridge-swagger]
    Fetch a fresh trial key from public MAS, optionally reset it on local MAS, then run e2e and/or bridge swagger suites.

  start-container-stack
    Start the Dockerized integration stack used by mentor-tests.

  stop-container-stack
    Stop and cleanup the Dockerized integration stack.

  run-e2e
    Run mentor-tests core-flow UI suite against the active stack.

  run-bridge-swagger
    Run Mentor.Bridge public swagger API suite against the active stack.

  collect-diagnostics [optional-reason]
    Collect current runtime artifacts (git, docker, compose logs, container state) for automated analysis.

  reset-mas-test-key [<key>]
    Reset usage counters for an existing test key via MAS public API (default key: MM_KEY).

  smoke
    Start container stack, run run-e2e, and keep stack running.

  promote --from-channel Test --to-channel Staging --components daemon,bridge,ui [--version 1.2.3] [--test] [--debug] [--update-bin-repos] [--local-mas]

  promote-daemon-test-to-prerelease [--version 1.2.3] [--skip-smoke] [--execute]
    Validate daemon Test -> Pre-Release path with local smoke (default) + optional real promotion.

  status
    Print container status for mentor-tests infrastructure.

Environment:
  MM_KEY                 Registration key for mentor-tests stack startup and auth flow
  CI_TEST_USER_NAME      Optional identity default for fetch-mm-key (defaults to QA Test User)
  CI_TEST_USER_EMAIL     Optional identity default for fetch-mm-key (defaults to qa-test@merly.ai)
  E2E_UI_BASE_URL        UI base url for tests (default: http://localhost:3000)
  BRIDGE_TEST_EMAIL       Email used for Mentor.Bridge public swagger test auth
  BRIDGE_TEST_PASSWORD    Password used for Mentor.Bridge public swagger test auth
  BRIDGE_TEST_API_VERSION API version for TestSwagger_* runs (v1, v2, all)
  BRIDGE_TEST_PATTERN     go test -run pattern (default: ^TestSwagger_)
  BRIDGE_TEST_RUN_SETUP   Set to 0 to skip TestSetup_FromScratch pre-run (default: 1)
  BRIDGE_TEST_URL         Bridge base url for public swagger suite (default: http://localhost:8080)
  THREAD_RUNTIME_DIAG_DIR  Local directory for automation diagnostics artifacts (default: .thread-runtime-diagnostics)
  THREAD_RUNTIME_DIAGNOSTICS_CONTAINER_LIMIT  Maximum containers captured when compose service discovery is unavailable (default: 10)
  THREAD_RUNTIME_DIAGNOSTICS  Set to 0 to disable automatic diagnostics capture (default: 1)
  THREAD_RUNTIME_DIAGNOSTICS_ON_ERROR  Set to 0 to disable automatic error-only diagnostics (default: 1)
  MAS_API_BASE_URL        Public MAS host for key operations (default: https://merlyserviceadmin.azurewebsites.net)
  MAS_RESET_WHO           who parameter for /api/License/ResetTestUsage (default: qa-reset-bot)
  LOCAL_MAS_API_BASE_URL  Default local MAS host for key reset in `run-local-tests-with-public-key` (default: http://localhost:5002)
  PUSH_TOKEN             Required by promote command for git operations
  COMPONENTS             Default components for promote command: daemon,bridge,ui
  FROM_CHANNEL           Default source channel for promote command: Test
  TO_CHANNEL             Default target channel for promote command: Staging
EOF
}


wait_for_http() {
  local url=$1
  local label=$2
  local timeout_seconds=${3:-120}
  local elapsed=0

  until curl -s -o /dev/null "$url" >/dev/null 2>&1; do
    sleep 2
    elapsed=$((elapsed + 2))
    if ((elapsed >= timeout_seconds)); then
      echo "error: timed out waiting for ${label} at ${url}" >&2
      exit 1
    fi
  done
}

url_encode() {
  python3 - "$1" <<'PY'
import sys
from urllib.parse import quote
value = sys.argv[1] if len(sys.argv) > 1 else ""
print(quote(value))
PY
}

extract_mm_key_from_response() {
  local response_body="${1-}"
  python3 -c '
import json
import sys

raw = sys.stdin.read()
raw = raw.strip()
if not raw:
    sys.exit(1)

def extract_key(data):
    if isinstance(data, dict):
        for field in ("key", "trialKey", "licenseKey"):
            value = data.get(field)
            if isinstance(value, str) and len(value) > 10:
                return value
        reg = data.get("registration")
        if isinstance(reg, dict):
            reg_key = reg.get("key")
            if isinstance(reg_key, str) and len(reg_key) > 10:
                return reg_key
    return ""

try:
    data = json.loads(raw)
    if isinstance(data, str):
        data = json.loads(data)
    key = extract_key(data)
    if key:
        print(key)
        raise SystemExit(0)
except json.JSONDecodeError:
    pass

sys.exit(1)
' <<< "$response_body"
}

cmd_fetch_mm_key() {
  local username="${CI_TEST_USER_NAME:-QA Test User}"
  local email="${CI_TEST_USER_EMAIL:-qa-test@merly.ai}"
  local endpoint="https://merlyserviceadmin.azurewebsites.net"

  while (($# > 0)); do
    case "$1" in
      --username)
        username="$2"
        shift 2
        ;;
      --username=*)
        username="${1#*=}"
        shift
        ;;
      --email)
        email="$2"
        shift 2
        ;;
      --email=*)
        email="${1#*=}"
        shift
        ;;
      --endpoint)
        endpoint="$2"
        shift 2
        ;;
      --endpoint=*)
        endpoint="${1#*=}"
        shift
        ;;
      *)
        echo "error: unknown fetch-mm-key argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  require curl
  require python3

  if [[ -z "${username}" || -z "${email}" ]]; then
    echo "error: username and email are required for MM_KEY fetch" >&2
    exit 1
  fi

  local encoded_username
  local encoded_email
  encoded_username=$(url_encode "$username")
  encoded_email=$(url_encode "$email")
  local url="${endpoint}/api/TrialRegistration/GetOrCreateKey?username=${encoded_username}&email=${encoded_email}"
  local response_http
  local response_body
  local http_code

  response_http="$(curl -sS -w "\nHTTP_CODE:%{http_code}" -X POST "$url" -H "Accept: application/json")"
  http_code="$(printf '%s' "$response_http" | grep "^HTTP_CODE:" | sed 's/^HTTP_CODE://')"
  response_body="$(printf '%s' "$response_http" | sed '/^HTTP_CODE:/d')"

  if [[ -z "${http_code}" || ! "${http_code}" =~ ^[0-9]+$ ]]; then
    echo "error: unable to parse HTTP code from MAS response" >&2
    exit 1
  fi

  if ((http_code < 200 || http_code >= 300)); then
    echo "error: TrialRegistration API returned HTTP ${http_code}" >&2
    echo "details: ${response_body}" >&2
    exit 1
  fi

  if [[ -z "${response_body}" ]]; then
    echo "error: MAS response body was empty" >&2
    exit 1
  fi

  local product_key
  product_key="$(extract_mm_key_from_response "$response_body")"

  if [[ -z "${product_key}" || ${#product_key} -le 10 ]]; then
    echo "error: could not parse MM_KEY from MAS response" >&2
    echo "response_body: ${response_body}" >&2
    exit 1
  fi

  echo "${product_key}"
}

cmd_run_local_tests_with_public_key() {
  local username="${CI_TEST_USER_NAME:-QA Test User}"
  local email="${CI_TEST_USER_EMAIL:-qa-test@merly.ai}"
  local remote_endpoint="https://merlyserviceadmin.azurewebsites.net"
  local local_endpoint="${LOCAL_MAS_API_BASE_URL:-http://localhost:5002}"
  local who="${MAS_RESET_WHO:-qa-reset-bot}"
  local run_e2e=true
  local run_bridge=true
  local do_reset=true

  while (($# > 0)); do
    case "$1" in
      --username)
        username="$2"
        shift 2
        ;;
      --username=*)
        username="${1#*=}"
        shift
        ;;
      --email)
        email="$2"
        shift 2
        ;;
      --email=*)
        email="${1#*=}"
        shift
        ;;
      --remote-endpoint)
        remote_endpoint="$2"
        shift 2
        ;;
      --remote-endpoint=*)
        remote_endpoint="${1#*=}"
        shift
        ;;
      --local-mas-endpoint)
        local_endpoint="$2"
        shift 2
        ;;
      --local-mas-endpoint=*)
        local_endpoint="${1#*=}"
        shift
        ;;
      --who)
        who="$2"
        shift 2
        ;;
      --who=*)
        who="${1#*=}"
        shift
        ;;
      --no-reset)
        do_reset=false
        shift
        ;;
      --run-e2e)
        run_e2e=true
        shift
        ;;
      --run-bridge-swagger)
        run_bridge=true
        shift
        ;;
      --no-e2e)
        run_e2e=false
        shift
        ;;
      --no-bridge-swagger)
        run_bridge=false
        shift
        ;;
      *)
        echo "error: unknown run-local-tests-with-public-key argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  local mm_key
  mm_key="$(cmd_fetch_mm_key --username "$username" --email "$email" --endpoint "$remote_endpoint")"

  if [[ -z "$mm_key" ]]; then
    echo "error: failed to retrieve MM key for local test automation" >&2
    exit 1
  fi

  if [[ "$do_reset" == "true" ]]; then
    log "Resetting key usage on local MAS ${local_endpoint} for key ${mm_key}."
    MAS_RESET_WHO="$who" MAS_API_BASE_URL="$local_endpoint" cmd_reset_mas_test_key "$mm_key"
  else
    log "Skipping local MAS reset."
  fi

  local previous_mm_key="${MM_KEY-}"
  export MM_KEY="$mm_key"
  log "Prepared local MM_KEY=${MM_KEY}"

  if [[ "$run_e2e" == "true" ]]; then
    cmd_run_e2e
  fi

  if [[ "$run_bridge" == "true" ]]; then
    cmd_run_bridge_swagger
  fi

  if [[ -n "$previous_mm_key" ]]; then
    export MM_KEY="$previous_mm_key"
  else
    unset MM_KEY
  fi
}

cmd_check() {
  log "Checking required commands..."
  require docker
  require curl
  require node
  require git
  if command -v npm >/dev/null 2>&1; then
    require npm
  fi
  log "Environment checks passed."
}

cmd_reset_bridge_test_state() {
  local mentor_dir="${ROOT_DIR}/mentor-tests/infrastructure/mentor"
  local reset_state="${BRIDGE_TEST_RESET_STATE:-1}"

  if [[ "$reset_state" != "1" ]]; then
    return 0
  fi

  log "Resetting mentor state artifacts for bridge swagger runs (BRIDGE_TEST_RESET_STATE=$reset_state)."
  mkdir -p "$mentor_dir"
  rm -f \
    "$mentor_dir/users.db" \
    "$mentor_dir/users.db-shm" \
    "$mentor_dir/users.db-wal" \
    "$mentor_dir/router.db" \
    "$mentor_dir/router.db-shm" \
    "$mentor_dir/router.db-wal" \
    "$mentor_dir/router.db-fail" \
    "$mentor_dir/router.db-set" \
    "$mentor_dir/router.db-success" \
    "$mentor_dir/router.db-set-bak" \
    "$mentor_dir/keys.json" \
    "$mentor_dir/settings.json" \
    "$mentor_dir/cpu_info.json" \
    "$mentor_dir/cpu_info_current.json" \
    "$mentor_dir/.pid"
}

cmd_reset_mas_test_key() {
  local key="${1:-${MM_KEY:-}}"
  local who="${MAS_RESET_WHO:-qa-reset-bot}"
  local api_base="${MAS_API_BASE_URL:-https://merlyserviceadmin.azurewebsites.net}"

  if [[ -z "${key}" ]]; then
    echo "error: MM_KEY is not set and no key was provided" >&2
    echo "Usage: ./scripts/thread-runtime.sh reset-mas-test-key [<key>]" >&2
    exit 1
  fi

  require curl

  local base
  base="${api_base%/}"
  local encoded_key
  local encoded_who
  local response_http
  local response_body
  local http_code

  encoded_key="$(url_encode "$key")"
  encoded_who="$(url_encode "$who")"
  response_http="$(curl -sS -w "\nHTTP_CODE:%{http_code}" \
    -X POST "${base}/api/License/ResetTestUsage?key=${encoded_key}&who=${encoded_who}" \
    -H "Accept: application/json")"
  http_code="$(printf '%s' "$response_http" | sed -n 's/^HTTP_CODE://p' | tail -n1)"
  response_body="$(printf '%s' "$response_http" | sed '/^HTTP_CODE:/d')"

  if [[ -z "${http_code}" || ! "${http_code}" =~ ^[0-9]+$ ]]; then
    echo "error: unable to parse HTTP code from MAS response" >&2
    exit 1
  fi

  if ((http_code < 200 || http_code >= 300)); then
    echo "error: MAS ResetTestUsage returned HTTP ${http_code}" >&2
    [[ -n "${response_body}" ]] && echo "details: ${response_body}" >&2
    exit 1
  fi

  if [[ -z "${response_body}" ]]; then
    echo "error: MAS reset response body was empty" >&2
    exit 1
  fi

  echo "MAS reset successful (HTTP ${http_code})"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$response_body" <<'PY'
import sys
import json
body = sys.argv[1]
try:
    data = json.loads(body)
except Exception:
    print(body)
else:
    print(json.dumps(data, indent=2, sort_keys=True))
PY
  else
    echo "${response_body}"
  fi
}

cmd_start_stack() {
  local key="${MM_KEY:-}"
  if [[ -z "${key}" ]]; then
    echo "error: MM_KEY is required for mentor-tests startup" >&2
    exit 1
  fi
  if [[ ! -f "$INFRA_COMPOSE" ]]; then
    echo "error: compose template missing at $INFRA_COMPOSE" >&2
    exit 1
  fi

  log "Starting mentor-tests infrastructure..."
  run_with_diag start_infra docker compose -f "$INFRA_COMPOSE" up -d
  log "Waiting for services..."
  wait_for_http "http://localhost:8080" "Bridge"
  wait_for_http "http://localhost:3000" "UI"
  log "Stack is up."
}

cmd_stop_stack() {
  if [[ ! -f "$INFRA_COMPOSE" ]]; then
    echo "error: compose template missing at $INFRA_COMPOSE" >&2
    exit 1
  fi
  log "Stopping mentor-tests infrastructure..."
  run_with_diag stop_infra docker compose -f "$INFRA_COMPOSE" down -v
}

cmd_status() {
  if [[ ! -f "$INFRA_COMPOSE" ]]; then
    echo "error: compose template missing at $INFRA_COMPOSE" >&2
    exit 1
  fi
  run_with_diag infra_status docker compose -f "$INFRA_COMPOSE" ps
}

cmd_run_e2e() {
  local ui_url="${E2E_UI_BASE_URL:-http://localhost:3000}"
  local mm_key="${MM_KEY:-}"

  if [[ -z "$mm_key" ]]; then
    echo "error: MM_KEY is required for mentor-tests" >&2
    exit 1
  fi
  if [[ ! -d "$TEST_DIR" ]]; then
    echo "error: mentor-tests directory missing at $TEST_DIR" >&2
    exit 1
  fi

  log "Running mentor-tests core flow from $TEST_DIR"
  (
    cd "$TEST_DIR"
    require npm
    require npx
    if [[ ! -d node_modules ]]; then
      run_with_diag_in_dir mentor_tests_npm_ci "$TEST_DIR" npm ci
    fi
    run_with_diag_in_dir mentor_tests_playwright_install "$TEST_DIR" npx playwright install --with-deps
    run_with_diag_in_dir mentor_tests_core_flow "$TEST_DIR" \
      env MM_KEY="$mm_key" E2E_UI_BASE_URL="$ui_url" npx playwright test
  )
}

cmd_run_bridge_swagger() {
  local bridge_url="${BRIDGE_TEST_URL:-http://bridge:8080}"
  local bridge_email="${BRIDGE_TEST_EMAIL:-}"
  local bridge_password="${BRIDGE_TEST_PASSWORD:-}"
  local api_version="${BRIDGE_TEST_API_VERSION:-v2}"
  local pattern="${BRIDGE_TEST_PATTERN:-^TestSwagger_}"
  local run_setup="${BRIDGE_TEST_RUN_SETUP:-1}"
  local mm_key="${MM_KEY:-}"
  local -a run_env=(
    "-e" "TEST_BASE_URL=$bridge_url"
    "-e" "TEST_API_VERSION=$api_version"
    "-e" "BRIDGE_TEST_PATTERN=$pattern"
    "-e" "BRIDGE_TEST_URL=$bridge_url"
    "-e" "MERLY_MENTOR_DIR=/app/.mentor"
  )
  if [[ -n "$bridge_email" ]]; then
    run_env+=("-e" "TEST_EMAIL=$bridge_email")
  fi
  if [[ -n "$bridge_password" ]]; then
    run_env+=("-e" "TEST_PASSWORD=$bridge_password")
  fi

  if [[ -z "$mm_key" ]]; then
    echo "error: MM_KEY is required for mentor-tests stack and bridge swagger suite" >&2
    exit 1
  fi

  log "Preparing mentor-tests stack for Mentor.Bridge public swagger suite."
  cmd_reset_bridge_test_state
  cmd_start_stack

  if [[ "$run_setup" == "1" ]]; then
    log "Running Mentor.Bridge setup bootstrap before swagger suite."
    run_with_diag run_bridge_swagger_setup \
      docker compose -f "$INFRA_COMPOSE" --profile bridge-swagger run --rm --no-deps \
      -e "TEST_BASE_URL=$bridge_url" \
      -e "TEST_API_VERSION=$api_version" \
      -e "REGISTRATION_KEY=$mm_key" \
      -e "MERLY_MENTOR_DIR=/app/.mentor" \
      bridge-swagger-tests \
      bash -lc 'set -o pipefail; export PATH="/usr/local/go/bin:$PATH"; mkdir -p "${BRIDGE_TEST_REPORT_DIR:-/tmp/bridge-swagger}"; go test -run "^TestSetup_FromScratch$" -count=1 -v ./...'
    log "Restarting bridge service to refresh mentor state after setup."
    run_with_diag restart_bridge_for_setup \
      docker compose -f "$INFRA_COMPOSE" restart bridge
    wait_for_http "http://localhost:8080" "Bridge (post-setup restart)"
  fi

  if [[ "${bridge_email}" == "" ]]; then
    echo "BRIDGE_TEST_EMAIL not set; using EMAIL from .env if present."
  elif [[ "${bridge_password}" == "" ]]; then
    echo "warning: BRIDGE_TEST_PASSWORD is empty for TEST_EMAIL=$bridge_email"
  fi

  local bridge_swagger_report_dir="${DIAG_SESSION_DIR}/bridge-swagger"
  mkdir -p "$bridge_swagger_report_dir"

  log "Running Mentor.Bridge public swagger suite from bridge service."
  run_with_diag run_bridge_swagger \
    docker compose -f "$INFRA_COMPOSE" --profile bridge-swagger run --rm --no-deps \
    "${run_env[@]}" \
    -v "${bridge_swagger_report_dir}:/artifacts" \
    -e "BRIDGE_TEST_REPORT_DIR=/artifacts" \
    bridge-swagger-tests \
    bash -lc 'set -o pipefail; export PATH="/usr/local/go/bin:$PATH"; mkdir -p "${BRIDGE_TEST_REPORT_DIR:-/tmp/bridge-swagger}"; json_file="${BRIDGE_TEST_REPORT_DIR:-/tmp/bridge-swagger}/go-test.json"; go test -run "${BRIDGE_TEST_PATTERN:-^TestSwagger_}" -count=1 -json ./... | tee "$json_file"; test_rc=${PIPESTATUS[0]}; python3 - "$json_file" <<'"'"'PY'"'"'
import json
import sys

json_file = sys.argv[1]
stats = {"run": 0, "pass": 0, "fail": 0, "skip": 0}
failures = []

with open(json_file, "r", encoding="utf-8") as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except Exception:
            continue
        action = event.get("Action", "")
        test = event.get("Test")
        if not test:
            continue
        if action in stats:
            stats[action] = stats.get(action, 0) + 1
        if action == "fail":
            failures.append(test)

total = stats["pass"] + stats["fail"] + stats["skip"]
print(f"SUMMARY: total={total} passed={stats['"'"'pass'"'"']} failed={stats['"'"'fail'"'"']} skipped={stats['"'"'skip'"'"']}")
if failures:
    print("FAILED_TESTS:")
    for name in failures:
        print(f"- {name}")
PY
exit "$test_rc"
'
}

cmd_smoke() {
  cmd_start_stack
  cmd_run_e2e
}

cmd_promote() {
  local from_channel="${FROM_CHANNEL:-Test}"
  local to_channel="${TO_CHANNEL:-Staging}"
  local components="${COMPONENTS:-daemon,bridge,ui}"
  local version=""
  local test_mode=false
  local debug_mode=false
  local update_bin_repos=false
  local local_mas=false

  while (($# > 0)); do
    case "$1" in
      --from-channel)
        from_channel="$2"
        shift 2
        ;;
      --from-channel=*)
        from_channel="${1#*=}"
        shift
        ;;
      --to-channel)
        to_channel="$2"
        shift 2
        ;;
      --to-channel=*)
        to_channel="${1#*=}"
        shift
        ;;
      --components)
        components="$2"
        shift 2
        ;;
      --components=*)
        components="${1#*=}"
        shift
        ;;
      --version)
        version="$2"
        shift 2
        ;;
      --version=*)
        version="${1#*=}"
        shift
        ;;
      --test)
        test_mode=true
        shift
        ;;
      --debug)
        debug_mode=true
        shift
        ;;
      --update-bin-repos)
        update_bin_repos=true
        shift
        ;;
      --local-mas)
        local_mas=true
        shift
        ;;
      *)
        echo "error: unknown promote argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  if [[ ! -f "$PUSH_CHANNEL_SCRIPT" ]]; then
    echo "error: missing push-channel script at $PUSH_CHANNEL_SCRIPT" >&2
    exit 1
  fi
  if [[ -z "${PUSH_TOKEN:-}" ]]; then
    echo "error: PUSH_TOKEN is required for promote" >&2
    exit 1
  fi

  local push_args=(
    "--from_channel=$from_channel"
    "--to_channel=$to_channel"
    "--components=$components"
  )
  if [[ -n "$version" ]]; then
    push_args+=("--version=$version")
  fi
  if [[ "$test_mode" == "true" ]]; then
    push_args+=("--test")
  fi
  if [[ "$debug_mode" == "true" ]]; then
    push_args+=("--debug")
  fi
  if [[ "$update_bin_repos" == "true" ]]; then
    push_args+=("--update-bin-repos")
  fi
  if [[ "$local_mas" == "true" ]]; then
    push_args+=("--local_mas")
  fi

  log "Running promote command: $from_channel -> $to_channel (${components})"
  if [[ -n "$version" ]]; then
    log "Using specific version: $version"
  else
    log "Using latest version in source channel"
  fi

  run_with_diag promote \
    bash -lc "cd '${ROOT_DIR}/Merly.Installer' && python3 push-channel.py ${push_args[*]}"
}

cmd_promote_daemon_test_to_prerelease() {
  local version=""
  local skip_smoke=false
  local execute_real=false

  while (($# > 0)); do
    case "$1" in
      --version)
        version="$2"
        shift 2
        ;;
      --version=*)
        version="${1#*=}"
        shift
        ;;
      --skip-smoke)
        skip_smoke=true
        shift
        ;;
      --execute)
        execute_real=true
        shift
        ;;
      --test)
        # explicit no-op; validation mode is always used for this helper
        shift
        ;;
      *)
        echo "error: unknown promote-daemon-test-to-prerelease argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  if [[ "$skip_smoke" == "false" ]]; then
    log "Running default validation smoke before daemon promotion."
    cmd_smoke
  fi

  local promote_args=(
    "--from-channel"
    "Test"
    "--to-channel"
    "Pre-Release"
    "--components"
    "daemon"
  )
  if [[ -n "$version" ]]; then
    promote_args+=(--version "$version")
  fi

  log "Running Test -> Pre-Release daemon promotion in validation mode."
  cmd_promote "${promote_args[@]}" --test

  if [[ "$execute_real" != "true" ]]; then
    log "Validation mode complete. Add --execute to perform real Test -> Pre-Release promotion."
    return
  fi

  log "Executing real Test -> Pre-Release daemon promotion."
  cmd_promote "${promote_args[@]}"
  log "Real daemon promotion completed. Validate QA dispatch and run follow-up e2e checks."
}

cmd_collect_diagnostics() {
  local reason="${1:-manual}"
  collect_runtime_diagnostics "$reason"
  log "Diagnostics written to: ${LAST_DIAGNOSTICS_PATH}"
}

  case "${1:-help}" in
  check)
    cmd_check
    ;;
  fetch-mm-key)
    shift
    cmd_fetch_mm_key "$@"
    ;;
  run-local-tests-with-public-key)
    shift
    cmd_run_local_tests_with_public_key "$@"
    ;;
  start-container-stack)
    cmd_start_stack
    ;;
  stop-container-stack)
    cmd_stop_stack
    ;;
  status)
    cmd_status
    ;;
  run-e2e)
    cmd_run_e2e
    ;;
  run-bridge-swagger)
    cmd_run_bridge_swagger
    ;;
  reset-mas-test-key)
    shift
    cmd_reset_mas_test_key "$@"
    ;;
  collect-diagnostics)
    shift
    cmd_collect_diagnostics "$@"
    ;;
  smoke)
    cmd_smoke
    ;;
  promote)
    shift
    cmd_promote "$@"
    ;;
  promote-daemon-test-to-prerelease)
    shift
    cmd_promote_daemon_test_to_prerelease "$@"
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    usage
    echo
    echo "error: unknown command '$1'" >&2
    exit 1
    ;;
esac
