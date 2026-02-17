#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_COMPOSE="${ROOT_DIR}/mentor-tests/infrastructure/docker-compose.yml"
TEST_DIR="${ROOT_DIR}/mentor-tests"
PUSH_CHANNEL_SCRIPT="${ROOT_DIR}/Merly.Installer/push-channel.py"

log() {
  echo "[$(date '+%H:%M:%S')] $*"
}

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

  start-container-stack
    Start the Dockerized integration stack used by mentor-tests.

  stop-container-stack
    Stop and cleanup the Dockerized integration stack.

  run-e2e
    Run mentor-tests core-flow UI suite against the active stack.

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
  docker compose -f "$INFRA_COMPOSE" up -d
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
  docker compose -f "$INFRA_COMPOSE" down -v
}

cmd_status() {
  if [[ ! -f "$INFRA_COMPOSE" ]]; then
    echo "error: compose template missing at $INFRA_COMPOSE" >&2
    exit 1
  fi
  docker compose -f "$INFRA_COMPOSE" ps
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
      log "Installing dependencies..."
      npm ci
    fi
    log "Installing playwright browsers if needed..."
    npx playwright install --with-deps
    log "Running core-flow test suite..."
    MM_KEY="$mm_key" E2E_UI_BASE_URL="$ui_url" npx playwright test
  )
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

  (cd "${ROOT_DIR}/Merly.Installer" && python3 push-channel.py "${push_args[@]}")
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

  case "${1:-help}" in
  check)
    cmd_check
    ;;
  fetch-mm-key)
    shift
    cmd_fetch_mm_key "$@"
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
