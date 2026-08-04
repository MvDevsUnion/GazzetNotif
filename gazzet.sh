#!/usr/bin/env bash
set -euo pipefail

BOT_TOKEN="devs_will_unionize"
CHANNEL_ID="reject_mdpnc"
SENT_LOG="$HOME/.gazzet_sent"
TELEGRAM_API="https://api.telegram.org/bot${BOT_TOKEN}"

IGNORE_MEMORY=false
if [[ "${1:-}" == "--ignore-memory" ]]; then
  IGNORE_MEMORY=true
fi

touch "$SENT_LOG" 2>/dev/null || true

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed." >&2
  exit 1
fi

BASE_URL="https://gazzette.idhaan.me/search"
VENDOR_DV="މާލޭ ސިޓީ ކައުންސިލްގެ އިދާރާ"
VENDOR_EN_SLUG="secretariat-of-the-male-city-council"
TODAY=$(date +%Y-%m-%d)
PAGE=1
TOTAL_PAGES=1
MAX_PAGES=20

send_message() {
  local id="$1" msg="$2"
  local attempt=1
  while [ "$attempt" -le 5 ]; do
    send_result=$(curl -s -X POST "${TELEGRAM_API}/sendMessage" \
      -d "chat_id=${CHANNEL_ID}" \
      -d "parse_mode=HTML" \
      -d "text=${msg}")

    ok=$(echo "$send_result" | jq -r '.ok // false' 2>/dev/null || echo false)
    if [[ "$ok" == "true" ]]; then
      echo "$id" >> "$SENT_LOG"
      echo "  → Published to @MccGazzette"
      return 0
    fi

    retry_after=$(echo "$send_result" | jq -r '.parameters.retry_after // 0' 2>/dev/null || echo 0)
    desc=$(echo "$send_result" | jq -r '.description // "unknown"' 2>/dev/null || echo "unknown")
    if [[ "$desc" == *"Too Many Requests"* ]]; then
      sleep "$retry_after"
      attempt=$((attempt + 1))
      continue
    fi

    echo "  → Telegram error: ${desc}"
    return 1
  done
  echo "  → Telegram error: gave up after 5 attempts (Too Many Requests)"
  return 1
}

echo "============================================"
echo "  Gazzette Iulaan Listings for $TODAY"
echo "============================================"
echo ""

while [ "$PAGE" -le "$TOTAL_PAGES" ] && [ "$PAGE" -le "$MAX_PAGES" ]; do
  response=$(curl -s "${BASE_URL}?page=${PAGE}&open_only=0&start_date=${TODAY}&end_date=${TODAY}" \
    -H 'accept: application/json')

  if ! echo "$response" | jq -e '.content.results' >/dev/null 2>&1; then
    echo "  → Warning: unexpected API response on page $PAGE (non-JSON or missing results); skipping."
    break
  fi

  if [ "$PAGE" -eq 1 ]; then
    TOTAL_PAGES=$(echo "$response" | jq -r '.content.meta_data.total_pages // "1"')
    TOTAL_RESULTS=$(echo "$response" | jq -r '.content.meta_data.total_results // "0"')
    if [[ "$TOTAL_PAGES" == "0" ]] || [[ "$TOTAL_PAGES" == "null" ]]; then
      TOTAL_PAGES=1
    fi
    echo "Total: $TOTAL_RESULTS listings across $TOTAL_PAGES pages (filtering for ${VENDOR_DV})"
    echo ""
  fi

  echo "--- Page $PAGE of $TOTAL_PAGES ---"
  echo ""

  count=0
  while IFS= read -r item; do
    [ -z "$item" ] && continue
    id=$(echo "$item" | jq -r '.id')
    title=$(echo "$item" | jq -r '.title // "N/A"')
    vendor=$(echo "$item" | jq -r '.vendor // "N/A"')
    vendor_url=$(echo "$item" | jq -r '.vendor_url // ""')
    iulaan_type=$(echo "$item" | jq -r '.iulaan_type // "N/A"')
    deadline=$(echo "$item" | jq -r '.deadline // "N/A"')
    deadline=${deadline%%T*}
    date=$(echo "$item" | jq -r '.date // ""')
    url=$(echo "$item" | jq -r '.url // "N/A"')

    if [[ "$vendor" != *"$VENDOR_DV"* ]] && [[ "$vendor_url" != *"$VENDOR_EN_SLUG"* ]]; then
      continue
    fi
    if [[ "$date" != "$TODAY"* ]]; then
      continue
    fi

    count=$((count + 1))
    echo "───────────────────────────────"
    echo "Title:   $title"
    echo "Vendor:  $vendor"
    echo "Type:    $iulaan_type"
    echo "Deadline: $deadline"
    echo "URL:     $url"

    if ! $IGNORE_MEMORY && grep -qx "$id" "$SENT_LOG" 2>/dev/null; then
      echo "  → Skipped (already sent)"
      continue
    fi

    nl=$'\n'
    msg="<strong>${title}</strong>${nl}${vendor}${nl}${iulaan_type}${nl}${deadline}${nl}${nl}<a href=\"${url}\">Open on Gazette</a>"

    if send_message "$id" "$msg"; then
      sleep 1
    fi
  done < <(echo "$response" | jq -c '.content.results[]?')

  if [ "$count" -eq 0 ]; then
    echo "  (no matching ${VENDOR_DV} listings on this page)"
  fi
  echo ""

  PAGE=$((PAGE + 1))
done
