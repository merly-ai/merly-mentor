#!/usr/bin/env bash

set -euo pipefail

XDG_CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_PREFIX="${GH_CONFIG_PREFIX:-gh}"
PROFILE_MAPPER="${GH_PROFILE_MAPPER:-}"
DEFAULT_PROFILE="${GH_PROFILE_DEFAULT:-personal}"
PROFILE_OVERRIDE="${GH_PROJECT_PROFILE:-}"
PROJECT_MAP="${GH_WORKSPACE_PROFILE_MAP:-}"
PROFILE_FILE_OVERRIDE="${GH_WORKSPACE_PROFILE_FILE:-}"
IGNORE_ENV_TOKEN="${GHX_IGNORE_ENV_TOKEN:-1}"
PRESERVE_ENV_TOKEN="${GHX_PRESERVE_ENV_TOKEN:-0}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/ghx.sh <gh arguments...>

Description:
  Run gh using a per-codex-project config directory inferred from workspace .codex
  boundaries, with repository owner as fallback.

Env:
  GH_WORKSPACE_PROFILE_MAP
                      Comma-separated list of workspace mappings ("workspace:profile").
  GH_PROJECT_PROFILE   Explicit profile override
  GH_WORKSPACE_PROFILE_FILE
                      Path to a workspace mapping file (default:
                      <workspace>/.codex/ghx-workspace-profiles.conf)
  GHX_IGNORE_ENV_TOKEN Ignore GH_TOKEN/GITHUB_TOKEN by default (default: 1)
  GHX_PRESERVE_ENV_TOKEN
                      Keep env tokens and bypass isolation (set to 1 for opt-in use).
  GH_PROFILE_DEFAULT   Fallback profile name (default: personal)
  GH_CONFIG_PREFIX     Prefix for config folder (default: gh)
  GH_CONFIG_BASE       Base config directory (default: $XDG_CONFIG_HOME or $HOME/.config)
  GH_PROFILE_MAPPER    Optional mapping string "owner=profile" for one override case
                      "owner" mapping is used only if workspace mapping is unavailable.
EOF
}

if [[ $# -eq 0 ]]; then
  usage
  exit 2
fi

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

extract_owner() {
  local remote_url="$1"

  if [[ "$remote_url" =~ ^https?://github\.com/([^/]+)/[^/]+(\.git)?$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$remote_url" =~ ^git@github\.com:([^/]+)/[^/]+(\.git)?$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$remote_url" =~ ^ssh://git@github\.com/([^/]+)/[^/]+(\.git)?$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

repo_owner=""
repo_dir="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

resolve_workspace_profile() {
  local workspace_name="$1"

  case "$workspace_name" in
    merly.ai|merly_ai|merlyai|Merly.Ai)
      echo "merly-ai"
      return 0
      ;;
    Coherence-Network|coherence-network|coherence_network|coherence-network-codex|seeker71-workspace)
      echo "seeker71"
      return 0
      ;;
  esac

  return 1
}

resolve_custom_workspace_map() {
  local workspace_name="$1"
  local mapping_pair
  local mapping_name
  local mapping_profile

  IFS=',' read -r -a mappings <<< "${PROJECT_MAP:-}"
  for mapping_pair in "${mappings[@]}"; do
    [[ -z "$mapping_pair" ]] && continue
    mapping_name="${mapping_pair%%:*}"
    mapping_profile="${mapping_pair#*:}"
    if [[ "$workspace_name" == "$mapping_name" ]]; then
      echo "$mapping_profile"
      return 0
    fi
  done

  return 1
}

workspace_root="$repo_dir"
current_path="$repo_dir"
while [[ "$current_path" != "/" ]]; do
  if [[ -d "${current_path}/.codex" ]]; then
    workspace_root="$current_path"
    break
  fi
  parent_path="$(dirname "$current_path")"
  if [[ "$parent_path" == "$current_path" ]]; then
    break
  fi
  current_path="$parent_path"
done

workspace_name="$(basename "$workspace_root")"
workspace_profile=""
WORKSPACE_MAP_FILE="${PROFILE_FILE_OVERRIDE:-${workspace_root}/.codex/ghx-workspace-profiles.conf}"

if [[ -n "${PROJECT_MAP}" ]]; then
  workspace_profile="$(resolve_custom_workspace_map "$workspace_name")"
fi

if [[ -z "${workspace_profile}" && -f "$WORKSPACE_MAP_FILE" ]]; then
  while IFS= read -r mapping_line; do
    mapping_line="${mapping_line%%#*}"
    [[ -z "$mapping_line" ]] && continue
    IFS=':' read -r map_workspace map_profile <<< "$mapping_line"
    map_workspace="$(printf '%s' "$map_workspace" | tr -d '[:space:]')"
    map_profile="$(printf '%s' "$map_profile" | tr -d '[:space:]')"
    if [[ -n "$map_workspace" && -n "$map_profile" && "$map_workspace" != \#* ]]; then
      if [[ "$workspace_name" == "$map_workspace" ]]; then
        workspace_profile="$map_profile"
        break
      fi
    fi
  done < "$WORKSPACE_MAP_FILE"
fi

if [[ -z "${workspace_profile}" ]]; then
  workspace_profile="$(resolve_workspace_profile "$workspace_name")"
fi

for remote_name in origin upstream fork; do
  remote_url="$(git -C "$repo_dir" remote get-url "$remote_name" 2>/dev/null || true)"
  if [[ -n "$remote_url" ]]; then
    owner="$(extract_owner "$remote_url" || true)"
    if [[ -n "$owner" ]]; then
      repo_owner="$owner"
      break
    fi
  fi
done

if [[ -n "${PROFILE_OVERRIDE}" ]]; then
  profile="${PROFILE_OVERRIDE}"
elif [[ -n "${workspace_profile}" ]]; then
  profile="${workspace_profile}"
elif [[ -n "$repo_owner" ]]; then
  case "$repo_owner" in
    merly-ai|Merly-AI|merly.ai|Merly.AI)
      profile="merly-ai"
      ;;
    urs-muff|urs_muff|Urs-Muff|URSMUFF)
      profile="urs-muff"
      ;;
    *)
      profile="${DEFAULT_PROFILE}"
      ;;
  esac
else
  profile="${DEFAULT_PROFILE}"
fi

if [[ -n "${PROFILE_MAPPER}" ]]; then
  mapped_profile="${PROFILE_MAPPER%%=*}"
  mapping_suffix="${PROFILE_MAPPER#*=}"
  if [[ "$repo_owner" == "$mapped_profile" ]]; then
    profile="${mapping_suffix}"
  fi
fi

config_base="${GH_CONFIG_BASE:-$XDG_CONFIG_ROOT}"
export GH_CONFIG_DIR="${config_base}/${CONFIG_PREFIX}-${profile}"
mkdir -p "$GH_CONFIG_DIR"

if [[ "$PRESERVE_ENV_TOKEN" != "1" && "$IGNORE_ENV_TOKEN" == "1" ]]; then
  unset GH_TOKEN
  unset GITHUB_TOKEN
  unset GH_ENTERPRISE_TOKEN
  unset GITHUB_ENTERPRISE_TOKEN
fi

exec gh "$@"
