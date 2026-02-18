#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REPOS=(
  "Mentor.Bridge"
  "Mentor.UI"
  "Merly.Installer"
  "Merly.WebPortal"
  "mentor-tests"
  "merly-mentor"
  "debugging"
  "MP-CodeCheckBin-MacOS"
  "MP-CodeCheckBin-Suse"
  "MP-CodeCheckBin-Windows"
)

REMOTE="${REMOTE:-origin}"
BRANCH="${BRANCH:-}"
DRY_RUN=0
PUSH_ARGS=("--follow-tags")
FILTER_REPOS=()
SKIP_MISSING=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/push-thread-repos.sh [options]

Description:
  Push a single branch to multiple workspace repositories.

Options:
  --remote <name>       Remote name to push to (default: origin or REMOTE env var)
  --branch <name>       Branch to push (default: current branch in each repo or BRANCH env var)
  --repo <path>         Restrict to one repo (can be repeated)
  --skip-missing         Skip missing repos instead of failing
  --dry-run              Print commands without pushing
  --no-follow-tags       Skip pushing tags
  -h, --help            Show this message

Examples:
  ./scripts/push-thread-repos.sh --remote origin --branch codex/my-thread
  REMOTE=fork BRANCH=my-thread ./scripts/push-thread-repos.sh --repo Mentor.Bridge
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote)
      REMOTE="${2:?--remote requires a value}"
      shift 2
      ;;
    --branch)
      BRANCH="${2:?--branch requires a value}"
      shift 2
      ;;
    --repo)
      FILTER_REPOS+=("${2:?--repo requires a value}")
      shift 2
      ;;
    --skip-missing)
      SKIP_MISSING=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --no-follow-tags)
      PUSH_ARGS=()
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      echo "Try: ./scripts/push-thread-repos.sh --help" >&2
      exit 2
      ;;
  esac
done

ACTIVE_REPOS=("${REPOS[@]}")
if (( ${#FILTER_REPOS[@]} > 0 )); then
  ACTIVE_REPOS=("${FILTER_REPOS[@]}")
fi

if [[ -n "${THREAD_PUSH_REPOS:-}" ]]; then
  IFS=',' read -r -a env_repos <<< "${THREAD_PUSH_REPOS}"
  if (( ${#env_repos[@]} > 0 )); then
    ACTIVE_REPOS=("${env_repos[@]}")
  fi
fi

if (( ${#ACTIVE_REPOS[@]} == 0 )); then
  echo "error: no repos selected." >&2
  exit 1
fi

if [[ -n "${THREAD_PUSH_BRANCH:-}" ]]; then
  BRANCH="${THREAD_PUSH_BRANCH}"
fi

TOTAL_SUCCESS=0
TOTAL_FAILURE=0
FAILURES=()

echo "[push-thread-repos] remote=${REMOTE} branch=${BRANCH:-<current>} repos=${#ACTIVE_REPOS[@]} dry_run=${DRY_RUN}"

for repo in "${ACTIVE_REPOS[@]}"; do
  repo_path="${ROOT_DIR}/${repo}"
  if [[ ! -d "${repo_path}" ]]; then
    msg="missing_path ${repo}"
    if (( SKIP_MISSING == 1 )); then
      echo "SKIP missing repo: ${repo_path}"
      continue
    fi
    echo "ERROR ${msg}" >&2
    ((TOTAL_FAILURE++))
    FAILURES+=("${msg}")
    continue
  fi

  if [[ ! -d "${repo_path}/.git" ]]; then
    msg="not_a_git_repo ${repo}"
    if (( SKIP_MISSING == 1 )); then
      echo "SKIP not git: ${repo}"
      continue
    fi
    echo "ERROR ${msg}" >&2
    ((TOTAL_FAILURE++))
    FAILURES+=("${msg}")
    continue
  fi

  if ! git -C "${repo_path}" remote get-url "${REMOTE}" >/dev/null 2>&1; then
    msg="missing_remote ${repo}: ${REMOTE}"
    echo "ERROR ${msg}" >&2
    ((TOTAL_FAILURE++))
    FAILURES+=("${msg}")
    continue
  fi

  local_branch="${BRANCH}"
  if [[ -z "${local_branch}" ]]; then
    local_branch="$(git -C "${repo_path}" rev-parse --abbrev-ref HEAD)"
  else
    if [[ "$(git -C "${repo_path}" rev-parse --abbrev-ref HEAD)" != "${local_branch}" ]]; then
      if ! git -C "${repo_path}" show-ref --verify --quiet "refs/heads/${local_branch}"; then
        msg="missing_local_branch ${repo}: ${local_branch}"
        echo "ERROR ${msg}" >&2
        ((TOTAL_FAILURE++))
        FAILURES+=("${msg}")
        continue
      fi
      if [[ "${DRY_RUN}" == "1" ]]; then
        echo "DRY-RUN [${repo}] checkout ${local_branch}"
      else
        git -C "${repo_path}" checkout "${local_branch}"
      fi
    fi
  fi

  push_cmd=(git -C "${repo_path}" push "${PUSH_ARGS[@]}" "${REMOTE}" "${local_branch}")
  if [[ "${DRY_RUN}" == "1" ]]; then
    echo "DRY-RUN [${repo}] ${push_cmd[*]}"
    continue
  fi

  if "${push_cmd[@]}"; then
    echo "OK pushed ${repo} (${local_branch} -> ${REMOTE})"
    ((TOTAL_SUCCESS++))
  else
    echo "ERROR push_failed ${repo} (${local_branch} -> ${REMOTE})" >&2
    ((TOTAL_FAILURE++))
    FAILURES+=("${repo}: push failed")
  fi
done

echo "[push-thread-repos] success=${TOTAL_SUCCESS} failures=${TOTAL_FAILURE}"
if (( TOTAL_FAILURE > 0 )); then
  echo "Failures:"
  for failure in "${FAILURES[@]}"; do
    echo "  - ${failure}"
  done
  exit 1
fi

exit 0
