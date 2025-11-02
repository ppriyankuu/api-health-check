#!/usr/bin/env bash

# Usage:
#   ./health-check.sh URL1 URL2 ...
#   ./health-check.sh --file urls.txt
#   ./health-check.sh --config config.json

set -euo pipefail

LOG_FILE="health-check.log"
FAILED_COUNT=0
ENDPOINTS=()  # will store "name|url" or "|url"

usage() {
  echo "Usage: $0 [--file FILE] [--config CONFIG] [URL...]"
  echo "  Checks HTTP status of given URLs."
  echo "  Logs failures with timestamps to $LOG_FILE."
  exit 1
}

log_failure() {
  local display_name="$1"
  local url="$2"
  local status="$3"
  local time_iso
  time_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local msg="[$time_iso] FAILED: ${display_name:-$url} → HTTP $status ($url)"
  echo "$msg" | tee -a "$LOG_FILE"
}

check_endpoint() {
  local display_name="$1"
  local url="$2"
  local label="${display_name:-$url}"

  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url")

  if [[ $status -ge 200 && $status -lt 400 ]]; then
    echo "✓ OK: $label ($status)"
  else
    log_failure "$display_name" "$url" "$status"
    ((FAILED_COUNT++))
  fi
}

if [[ $# -eq 0 ]]; then
  usage
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      if [[ ! -f "$2" ]]; then
        echo "Error: File '$2' not found." >&2
        exit 1
      fi
      while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        ENDPOINTS+=("|$line")  # no name
      done < "$2"
      shift 2
      ;;

    --config)
      if [[ ! -f "$2" ]]; then
        echo "Error: Config file '$2' not found." >&2
        exit 1
      fi
      if ! command -v jq >/dev/null 2>&1; then
        echo "Error: 'jq' is required for JSON config but not installed." >&2
        exit 1
      fi

      if ! jq '.endpoints // empty' "$2" >/dev/null; then
        echo "Error: Invalid config: missing 'endpoints' array." >&2
        exit 1
      fi

      while IFS= read -r item; do
        local name url
        name=$(echo "$item" | jq -r '.name // empty')
        url=$(echo "$item" | jq -r '.url // ""')
        if [[ -z "$url" ]]; then
          echo "Error: Missing 'url' in config entry: $item" >&2
          exit 1
        fi
        ENDPOINTS+=("${name}|${url}")
      done < <(jq -c '.endpoints[]' "$2")
      shift 2
      ;;

    --help|-h)
      usage
      ;;

    *)
      ENDPOINTS+=("|$1")
      shift
      ;;
  esac
done

if [[ ${#ENDPOINTS[@]} -eq 0 ]]; then
  echo "Error: No endpoints provided." >&2
  usage
fi

echo "Checking ${#ENDPOINTS[@]} endpoints..."

> "$LOG_FILE"

for ep in "${ENDPOINTS[@]}"; do
  IFS='|' read -r name url <<< "$ep"
  check_endpoint "$name" "$url"
done

echo ""
echo "Done. Failures: $FAILED_COUNT"

exit $((FAILED_COUNT > 255 ? 255 : FAILED_COUNT))

