#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/allow-azure-db-ip.sh --server <server-name> --resource-group <resource-group> [options]

Required:
  --server            Azure PostgreSQL server/flexible-server name
  --resource-group    Azure resource group containing the server

Options:
  --ip                IP address to allow (default: current public IP)
  --ip-range-end      End IP for a range (optional; if omitted defaults to --ip)
  --rule-name         Optional firewall rule name (default: codex-allow-<timestamp>)
  --flexible          Use flexible-server firewall rule command (detected automatically if omitted)
  --single             Force single-server firewall command
  --all               Allow 0.0.0.0-255.255.255.255 (debug-only)
  --list              List existing firewall rules then exit
  --help              Show this help
USAGE
}

get_public_ip() {
  curl -fsS https://api.ipify.org || curl -fsS https://ifconfig.me
}

log() {
  echo "[$(date '+%H:%M:%S')] $*"
}

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command '$1' is not installed or not on PATH" >&2
    exit 1
  fi
}

require az
require sed

server=""
resource_group=""
ip=""
end_ip=""
rule_name=""
mode="auto"
list_only=false

while (($# > 0)); do
  case "$1" in
    --server)
      server="$2"
      shift 2
      ;;
    --server=*)
      server="${1#*=}"
      shift
      ;;
    --resource-group)
      resource_group="$2"
      shift 2
      ;;
    --resource-group=*)
      resource_group="${1#*=}"
      shift
      ;;
    --ip)
      ip="$2"
      shift 2
      ;;
    --ip=*)
      ip="${1#*=}"
      shift
      ;;
    --ip-range-end)
      end_ip="$2"
      shift 2
      ;;
    --rule-name)
      rule_name="$2"
      shift 2
      ;;
    --rule-name=*)
      rule_name="${1#*=}"
      shift
      ;;
    --flexible)
      mode="flexible"
      shift
      ;;
    --single)
      mode="single"
      shift
      ;;
    --all)
      ip="0.0.0.0"
      end_ip="255.255.255.255"
      shift
      ;;
    --list)
      list_only=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$server" || -z "$resource_group" ]]; then
  echo "error: --server and --resource-group are required" >&2
  usage
  exit 1
fi

if [[ -z "$ip" ]]; then
  ip="$(get_public_ip)"
  if [[ -z "$ip" ]]; then
    echo "error: failed to resolve public IP automatically" >&2
    exit 1
  fi
fi

if [[ -z "$end_ip" ]]; then
  end_ip="$ip"
fi

if [[ -z "$rule_name" ]]; then
  rule_name="codex-allow-${ip}-$(date +%Y%m%d-%H%M%S)"
fi

if [[ "$mode" == "auto" ]]; then
  if az postgres flexible-server show --resource-group "$resource_group" --name "$server" >/dev/null 2>&1; then
    mode="flexible"
  elif az postgres server show --resource-group "$resource_group" --server-name "$server" >/dev/null 2>&1; then
    mode="single"
  else
    echo "error: could not find PostgreSQL server '$server' in resource group '$resource_group' (as single or flexible server)" >&2
    exit 1
  fi
fi

if [[ "$list_only" == true ]]; then
  if [[ "$mode" == "flexible" ]]; then
    az postgres flexible-server firewall-rule list --resource-group "$resource_group" --name "$server"
  else
    az postgres server firewall-rule list --resource-group "$resource_group" --server-name "$server"
  fi
  exit 0
fi

log "Server: $server"
log "Resource Group: $resource_group"
log "Mode: $mode"
log "Rule: $rule_name"
log "Allow range: $ip - $end_ip"

if [[ "$mode" == "flexible" ]]; then
  az postgres flexible-server firewall-rule create \
    --resource-group "$resource_group" \
    --name "$server" \
    --rule-name "$rule_name" \
    --start-ip-address "$ip" \
    --end-ip-address "$end_ip"
else
  az postgres server firewall-rule create \
    --resource-group "$resource_group" \
    --server-name "$server" \
    --name "$rule_name" \
    --start-ip-address "$ip" \
    --end-ip-address "$end_ip"
fi

a="Added firewall rule: $rule_name"
echo "$a"
