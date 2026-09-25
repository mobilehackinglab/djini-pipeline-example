#!/usr/bin/env bash
#
# djini-scan.sh — CI-friendly djini scan runner for GitHub Actions (and any CI).
#
# Uploads a mobile app build (.apk / .aab / .ipa) to a djini instance, starts a
# scan, polls until it finishes, downloads the PDF report, and gates the build on
# a configurable severity threshold.
#
# It is a hardened, CI-oriented version of the "example.sh" you can download from
# your djini user settings ("Pipeline integration"). Differences vs. that script:
#   * polls the dedicated /status endpoint instead of searching the scan list
#   * pulls machine-readable severity counts from the /findings endpoint
#   * writes a GitHub Step Summary + step outputs (project, status, counts)
#   * downloads a merged SARIF report for GitHub Code Scanning
#   * exits non-zero when findings meet/exceed --fail-on (so CI blocks the merge)
#
# Requires: bash, curl, jq
#
# Usage:
#   djini-scan.sh --file app.apk --api-key sk-... --base-url https://app.djini.ai \
#                 [--fail-on high] [--deep-scan] [--interval 60] [--timeout 5400] \
#                 [--output report.pdf] [--findings findings.json] [--sarif results.sarif] \
#                 [--skip-tls-verify] [--verbose]
#
# AI source scan (--source) is BYOK-only: it runs on YOUR OpenAI-compatible model.
# Either configure one once in djini (Settings -> BYOK), or pass it here and the
# script registers it on this API key's account before scanning:
#   djini-scan.sh --source ./app-src --api-key sk-... --base-url https://app.djini.ai \
#                 --source-llm-base-url https://openrouter.ai/api/v1 \
#                 --source-llm-key sk-or-... --source-llm-model qwen/qwen3.8-flash
#
# Every flag also has an env var fallback (handy for CI secrets):
#   API_KEY, BASE_URL, FAIL_ON, DEEP_SCAN, INTERVAL, TIMEOUT, OUTPUT, FINDINGS_JSON,
#   SARIF_OUT, SKIP_TLS_VERIFY, VERBOSE,
#   SOURCE_LLM_BASE_URL, SOURCE_LLM_KEY, SOURCE_LLM_MODEL
#
set -euo pipefail

# ── defaults ─────────────────────────────────────────────────────────────────
API_KEY="${API_KEY:-}"
BASE_URL="${BASE_URL:-}"
FILE=""
FAIL_ON="${FAIL_ON:-high}"        # critical | high | medium | low | none
DEEP_SCAN="${DEEP_SCAN:-}"        # non-empty => also run the deep scan
INTERVAL="${INTERVAL:-60}"        # poll interval (seconds)
TIMEOUT="${TIMEOUT:-5400}"        # give up after this many seconds (0 = no limit)
OUTPUT="${OUTPUT:-}"              # PDF report path
FINDINGS_JSON="${FINDINGS_JSON:-}"   # findings JSON path
SARIF_OUT="${SARIF_OUT:-}"       # SARIF report path (for GitHub Code Scanning)
SOURCE_DIR="${SOURCE_DIR:-}"     # if set: run the fast AI source scan on this source tree
# AI source scan is BYOK-only. When these are set, the script registers this
# OpenAI-compatible model on the API key's account (Settings -> BYOK) before scanning.
SOURCE_LLM_BASE_URL="${SOURCE_LLM_BASE_URL:-}"  # e.g. https://openrouter.ai/api/v1
SOURCE_LLM_KEY="${SOURCE_LLM_KEY:-}"            # key for that endpoint (blank => "not-needed")
SOURCE_LLM_MODEL="${SOURCE_LLM_MODEL:-}"        # e.g. qwen/qwen3.8-flash
SKIP_TLS_VERIFY="${SKIP_TLS_VERIFY:-}"
VERBOSE="${VERBOSE:-}"

# ── colors (auto-off when not a TTY, e.g. in CI logs) ────────────────────────
if [[ -t 1 ]]; then
  RED='\033[91m'; DARK_RED='\033[31m'; YELLOW='\033[33m'
  BLUE='\033[34m'; GREY='\033[37m'; GREEN='\033[32m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; DARK_RED=''; YELLOW=''; BLUE=''; GREY=''; GREEN=''; BOLD=''; RESET=''
fi

# ── helpers ──────────────────────────────────────────────────────────────────
header() { echo -e "\n${BOLD}$(printf '─%.0s' {1..60})${RESET}"; echo -e "${BOLD}  $1${RESET}"; echo -e "${BOLD}$(printf '─%.0s' {1..60})${RESET}"; }
die()    { echo -e "${RED}ERROR:${RESET} $*" >&2; exit 1; }

# GitHub Actions integration (no-ops outside GitHub Actions).
emit_output()  { [[ -n "${GITHUB_OUTPUT:-}"       ]] && echo "$1=$2" >> "$GITHUB_OUTPUT"       || true; }
summary()      { [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] && echo -e "$1" >> "$GITHUB_STEP_SUMMARY" || true; }

# ── arg parsing ──────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--file)          FILE="$2";            shift 2;;
    -k|--api-key)       API_KEY="$2";         shift 2;;
    -u|--base-url)      BASE_URL="$2";        shift 2;;
    --fail-on)          FAIL_ON="$2";         shift 2;;
    --deep-scan)        DEEP_SCAN=1;          shift;;
    -i|--interval)      INTERVAL="$2";        shift 2;;
    -t|--timeout)       TIMEOUT="$2";         shift 2;;
    -o|--output)        OUTPUT="$2";          shift 2;;
    --findings)         FINDINGS_JSON="$2";   shift 2;;
    --sarif)            SARIF_OUT="$2";       shift 2;;
    --source)           SOURCE_DIR="$2";      shift 2;;
    --source-llm-base-url) SOURCE_LLM_BASE_URL="$2"; shift 2;;
    --source-llm-key)      SOURCE_LLM_KEY="$2";      shift 2;;
    --source-llm-model)    SOURCE_LLM_MODEL="$2";    shift 2;;
    --skip-tls-verify)  SKIP_TLS_VERIFY=1;    shift;;
    -V|--verbose)       VERBOSE=1;            shift;;
    -h|--help)
      grep -E '^#( |$)' "$0" | sed -E 's/^# ?//'
      exit 0;;
    *) die "Unknown option: $1";;
  esac
done

# ── validation ───────────────────────────────────────────────────────────────
command -v curl >/dev/null 2>&1 || die "'curl' is required but not installed"
command -v jq   >/dev/null 2>&1 || die "'jq' is required but not installed"
[[ -n "$API_KEY"  ]] || die "No API key provided. Use --api-key or set API_KEY"
[[ -n "$BASE_URL" ]] || die "No base URL provided. Use --base-url or set BASE_URL"
if [[ -n "$SOURCE_DIR" ]]; then
  # Source-only scan: no binary needed.
  [[ -d "$SOURCE_DIR" ]] || die "Source dir not found: $SOURCE_DIR"
  command -v zip >/dev/null 2>&1 || die "'zip' is required for --source"
else
  [[ -n "$FILE" ]] || die "No file specified. Use --file (or --source for a source-only scan)"
  [[ -f "$FILE" ]] || die "File not found: $FILE"
fi

case "$FAIL_ON" in
  critical|high|medium|low|none) ;;
  *) die "--fail-on must be one of: critical, high, medium, low, none (got '$FAIL_ON')";;
esac

BASE_URL="${BASE_URL%/}"

[[ -n "$VERBOSE" ]] && set -x

CURL_OPTS=(-sS --fail-with-body)
[[ -n "$VERBOSE" ]]         && CURL_OPTS+=(-v)
[[ -n "$SKIP_TLS_VERIFY" ]] && CURL_OPTS+=(-k)
AUTH=(-H "Authorization: Bearer $API_KEY")

# Bound for `set -u`: the source-only path doesn't have a binary version.
APP_VERSION=""

# ── 1. create project + start scan ───────────────────────────────────────────
if [[ -n "$SOURCE_DIR" ]]; then
  # ── Source-only fast path ──────────────────────────────────────────────────
  # No binary upload/decompile: create the project straight from the source zip,
  # then run the AI source scan (MASVS swarm). Avoids the slow /upload path.
  header "Source"
  SRC_ZIP="$(mktemp -t djini-src-XXXX).zip"
  echo "  Packaging $SOURCE_DIR ..."
  ( cd "$SOURCE_DIR" && zip -qr "$SRC_ZIP" . \
      -x '*/build/*' '*/.gradle/*' '*/.git/*' '*/node_modules/*' '*/Pods/*' '*.apk' '*.aab' '*.ipa' )

  echo "  Uploading source to $BASE_URL ..."
  UPLOAD_RESP=$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" \
    -F "file=@$SRC_ZIP" \
    "${BASE_URL}/api/dashboard/scans/upload-source") || die "Source upload failed"
  rm -f "$SRC_ZIP"
  ERROR=$(echo "$UPLOAD_RESP" | jq -r '.error // empty')
  [[ -n "$ERROR" ]] && die "Source upload failed: $ERROR"
  PROJECT_NAME=$(echo "$UPLOAD_RESP" | jq -r '.projectName // empty')
  [[ -n "$PROJECT_NAME" ]] || die "Could not parse projectName from response: $UPLOAD_RESP"
  APP_NAME=$(echo "$UPLOAD_RESP" | jq -r '.appName // "unknown"')
  APP_VERSION=$(echo "$UPLOAD_RESP" | jq -r '.appVersion // .app_version // ""')
  PLATFORM=$(echo "$UPLOAD_RESP" | jq -r '.platform // "unknown"')
  echo "  App: $APP_NAME${APP_VERSION:+ v$APP_VERSION} ($PLATFORM)   Project: $PROJECT_NAME"
  emit_output "project" "$PROJECT_NAME"
  emit_output "app_name" "$APP_NAME"

  # The AI source scan is BYOK-only: it runs on your own OpenAI-compatible model.
  # When model creds are provided, register them on this API key's account first;
  # otherwise the account must already have an OpenAI-compatible model configured
  # (djini -> Settings -> BYOK) or the trigger below returns 400 byok_required.
  if [[ -n "$SOURCE_LLM_BASE_URL" || -n "$SOURCE_LLM_KEY" || -n "$SOURCE_LLM_MODEL" ]]; then
    [[ -n "$SOURCE_LLM_BASE_URL" ]] || die "--source-llm-base-url (or SOURCE_LLM_BASE_URL) is required to configure the source-scan model"
    [[ -n "$SOURCE_LLM_MODEL"    ]] || die "--source-llm-model (or SOURCE_LLM_MODEL) is required to configure the source-scan model"
    header "Configure AI model (BYOK)"
    echo "  Registering OpenAI-compatible model '$SOURCE_LLM_MODEL' for the AI source scan ..."
    BYOK_PAYLOAD=$(jq -n \
      --arg base "$SOURCE_LLM_BASE_URL" --arg key "${SOURCE_LLM_KEY:-not-needed}" --arg model "$SOURCE_LLM_MODEL" \
      '{providers:[{provider:"openai_compatible", baseUrl:$base, key:$key, model:$model}]}')
    BYOK_RESP=$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" \
      -X PUT -H "Content-Type: application/json" -d "$BYOK_PAYLOAD" \
      "${BASE_URL}/api/user-settings/byok") || die "Failed to configure the BYOK model"
    BYOK_ERR=$(echo "$BYOK_RESP" | jq -r '.error // empty')
    [[ -n "$BYOK_ERR" ]] && die "Failed to configure the BYOK model: $BYOK_ERR"
    echo "  Model configured."
  fi

  header "AI source scan"
  echo "  Starting AI source scan (MASVS swarm) for $PROJECT_NAME ..."
  SS_RESP=$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" \
    -X POST -H "Content-Type: application/json" -d '{}' \
    "${BASE_URL}/api/dashboard/scans/${PROJECT_NAME}/source-scan") || die "source-scan request failed"
  SS_CODE=$(echo "$SS_RESP" | jq -r '.code // empty')
  SS_ERROR=$(echo "$SS_RESP" | jq -r '.error // empty')
  if [[ "$SS_CODE" == "byok_required" ]]; then
    die "AI source scan needs your own OpenAI-compatible model. Pass --source-llm-base-url / --source-llm-key / --source-llm-model (or set SOURCE_LLM_* env), or configure one once in djini -> Settings -> BYOK."
  fi
  [[ -n "$SS_ERROR" ]] && die "AI source scan failed to start: $SS_ERROR"
  echo "  Scan started."
else
  # ── Full binary scan ───────────────────────────────────────────────────────
  header "Upload"
  FILENAME="$(basename "$FILE")"
  echo "  Uploading $FILENAME to $BASE_URL ..."
  UPLOAD_RESP=$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" \
    -F "file=@$FILE" \
    "${BASE_URL}/api/dashboard/upload") || die "Upload request failed"
  ERROR=$(echo "$UPLOAD_RESP" | jq -r '.error // empty')
  [[ -n "$ERROR" ]] && die "Upload failed: $ERROR"
  PROJECT_NAME=$(echo "$UPLOAD_RESP" | jq -r '.projectName // .project_name // empty')
  [[ -n "$PROJECT_NAME" ]] || die "Could not parse projectName from upload response: $UPLOAD_RESP"
  APP_NAME=$(echo "$UPLOAD_RESP"    | jq -r '.appName    // .app_name    // "unknown"')
  APP_VERSION=$(echo "$UPLOAD_RESP" | jq -r '.appVersion // .app_version // "?"')
  PLATFORM=$(echo "$UPLOAD_RESP"    | jq -r '.platform              // "unknown"')
  echo "  App:     $APP_NAME v$APP_VERSION ($PLATFORM)"
  echo "  Project: $PROJECT_NAME"
  emit_output "project" "$PROJECT_NAME"
  emit_output "app_name" "$APP_NAME"

  header "Process"
  # Set the scan depth explicitly so djini doesn't fall back to a server-side
  # default (or config inherited from a previous scan). deepScan defaults OFF;
  # enable with --deep-scan.
  DEEP_FLAG=false
  [[ -n "$DEEP_SCAN" ]] && DEEP_FLAG=true
  PROCESS_BODY=$(jq -nc --argjson deep "$DEEP_FLAG" '{deepScan: $deep, nativeScan: false}')
  echo "  Starting scan for $PROJECT_NAME (deepScan=$DEEP_FLAG) ..."
  PROCESS_RESP=$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" \
    -X POST -H "Content-Type: application/json" -d "$PROCESS_BODY" \
    "${BASE_URL}/api/dashboard/scans/${PROJECT_NAME}/process") || die "Process request failed"
  PROCESS_ERROR=$(echo "$PROCESS_RESP" | jq -r '.error // empty')
  [[ -n "$PROCESS_ERROR" ]] && die "Process failed: $PROCESS_ERROR"
  echo "  Scan started."
fi

# ── 3. poll ──────────────────────────────────────────────────────────────────
header "Polling scan: $PROJECT_NAME"
TERMINAL_STATUSES="Completed Error Cancelled Interrupted"
START_TS=$(date +%s)
ATTEMPT=0
STATUS="Unknown"

while true; do
  ATTEMPT=$((ATTEMPT + 1))
  ELAPSED=$(( $(date +%s) - START_TS ))

  if [[ "$TIMEOUT" -gt 0 && "$ELAPSED" -ge "$TIMEOUT" ]]; then
    die "Timed out after ${ELAPSED}s waiting for scan '$PROJECT_NAME' (last status: $STATUS)"
  fi

  STATUS_RESP=$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" \
    "${BASE_URL}/api/dashboard/scans/${PROJECT_NAME}/status") \
    || { echo "  [$ATTEMPT] Warning: status request failed, retrying..."; sleep "$INTERVAL"; continue; }

  STATUS=$(echo "$STATUS_RESP" | jq -r '.status // "Unknown"')
  DEEP_RUNNING=$(echo "$STATUS_RESP" | jq -r 'if .deepScanRunning then " (+deep scan)" else "" end')
  COMPONENTS=$(echo "$STATUS_RESP" | jq -r '(.componentStatuses // {}) | to_entries[] | "\(.key)=\(.value)"' | tr '\n' '  ')
  printf "  [%3d] %-16s elapsed=%-8s %s%s\n" "$ATTEMPT" "$STATUS" "${ELAPSED}s" "$COMPONENTS" "$DEEP_RUNNING"

  if echo "$TERMINAL_STATUSES" | grep -qw "$STATUS"; then
    # Wait for a running deep scan to finish before we gate on findings.
    if [[ -n "$DEEP_SCAN" && "$(echo "$STATUS_RESP" | jq -r '.deepScanRunning // false')" == "true" ]]; then
      sleep "$INTERVAL"; continue
    fi
    break
  fi
  sleep "$INTERVAL"
done

emit_output "status" "$STATUS"
[[ "$STATUS" == "Completed" ]] || die "Scan ended with status '$STATUS'"

# ── 4. findings (machine-readable) ───────────────────────────────────────────
header "Findings"
FINDINGS_JSON="${FINDINGS_JSON:-djini-findings.json}"
curl "${CURL_OPTS[@]}" "${AUTH[@]}" \
  "${BASE_URL}/api/dashboard/scans/${PROJECT_NAME}/findings" \
  -o "$FINDINGS_JSON" || die "Findings request failed"

get_count() { jq -r --arg k "$1" '(.severityCounts[$k] // 0)' "$FINDINGS_JSON"; }
CRITICAL=$(get_count Critical); HIGH=$(get_count High); MEDIUM=$(get_count Medium)
LOW=$(get_count Low);          INFO=$(get_count Informational)
TOTAL=$(jq -r '.totalFindings // 0' "$FINDINGS_JSON")
RISK=$(jq -r '.riskLevel // "?"' "$FINDINGS_JSON")

emit_output "critical" "$CRITICAL"; emit_output "high" "$HIGH"; emit_output "medium" "$MEDIUM"
emit_output "low" "$LOW"; emit_output "informational" "$INFO"; emit_output "total" "$TOTAL"

printf "  ${RED}Critical %d${RESET}  ${DARK_RED}High %d${RESET}  ${YELLOW}Medium %d${RESET}  ${GREEN}Low %d${RESET}  ${BLUE}Info %d${RESET}\n" \
  "$CRITICAL" "$HIGH" "$MEDIUM" "$LOW" "$INFO"
echo "  Total: $TOTAL   Risk level: $RISK"

# ── 5. download SARIF (for GitHub Code Scanning) ─────────────────────────────
header "SARIF"
SARIF_OUT="${SARIF_OUT:-djini-results.sarif}"
mkdir -p "$(dirname "$SARIF_OUT")"
if curl "${CURL_OPTS[@]}" "${AUTH[@]}" -o "$SARIF_OUT" \
     "${BASE_URL}/api/dashboard/scans/${PROJECT_NAME}/sarif?download=true"; then
  echo "  Saved: $SARIF_OUT"
  emit_output "sarif" "$SARIF_OUT"
else
  echo "  Note: no SARIF available for this scan (older djini instance or no static findings)."
fi

# ── 6. download PDF report ───────────────────────────────────────────────────
header "Report"
OUTPUT="${OUTPUT:-${PROJECT_NAME}.pdf}"
mkdir -p "$(dirname "$OUTPUT")"
if curl "${CURL_OPTS[@]}" "${AUTH[@]}" -o "$OUTPUT" \
     "${BASE_URL}/dashboard/scans/${PROJECT_NAME}/report?download=true"; then
  SIZE_KB=$(( $(wc -c < "$OUTPUT") / 1024 ))
  echo "  Saved: $OUTPUT  (${SIZE_KB} KB)"
  emit_output "report" "$OUTPUT"
else
  echo "  Warning: PDF report download failed (findings JSON is still available)."
fi

# ── 7. GitHub Step Summary ───────────────────────────────────────────────────
REPORT_URL="${BASE_URL}/dashboard/scans/${PROJECT_NAME}/report"
VER_SUFFIX=""
[[ -n "$APP_VERSION" && "$APP_VERSION" != "?" ]] && VER_SUFFIX=" v$APP_VERSION"
SCAN_TYPE_LABEL="Full Binary Scan"
[[ -n "$SOURCE_DIR" ]] && SCAN_TYPE_LABEL="AI Source Code Scan"
DJINI_LOGO='<img src="https://app.djini.ai/static/img/logo/Djini.svg" alt="Djini" height="40" align="absmiddle">'
summary "## $DJINI_LOGO Djini.AI Security Scan — \`$APP_NAME\`$VER_SUFFIX"
summary ""
summary "**Scan type:** $SCAN_TYPE_LABEL · **Project:** \`$PROJECT_NAME\` · **Platform:** $PLATFORM · **Risk level:** $RISK · **Gate:** \`--fail-on $FAIL_ON\`"
summary ""
# Clean, muted count badges (shields.io) — zeros go gray so the eye lands on
# what actually matters. GitHub strips CSS, so images are the way to get colour.
sev_badge() {  # $1=count  $2=hex colour when >0  $3=always (keep colour at 0)
  local color="$2"; [[ "${1:-0}" -eq 0 && -z "${3:-}" ]] && color="e5e7eb"
  echo "![${1}](https://img.shields.io/badge/${1}-${color}?style=flat-square)"
}
summary "| Severity | Findings |"
summary "|:---------|:---------|"
summary "| Critical      | $(sev_badge "$CRITICAL" a4161a) |"
summary "| High          | $(sev_badge "$HIGH" f3801f) |"
summary "| Medium        | $(sev_badge "$MEDIUM" e0b000) |"
summary "| Low           | $(sev_badge "$LOW" 30a46c) |"
summary "| Informational | $(sev_badge "$INFO" 4a90d9) |"
summary "| **Total**     | **$TOTAL** |"
summary ""

# ── Findings grouped by the 8 MASVS categories (from the SARIF) ──────────────
if [[ -f "$SARIF_OUT" && "$TOTAL" -gt 0 ]]; then
  ROWS=$(jq -r '
    .runs[].results[]?
    | (.properties.masvs // "Other") as $c
    | (.properties.severity // "Unknown") as $s
    | ({Critical:0,High:1,Medium:2,Low:3,Informational:4}[$s] // 5) as $r
    | (.properties.maswe // .ruleId // "") as $m
    | [ $c, ($r|tostring), $s, $m, ((.message.text // "") | split("—")[0] | gsub("^\\s+|\\s+$";"") | .[0:90]) ]
    | @tsv' "$SARIF_OUT" 2>/dev/null | sort -t"$(printf '\t')" -k1,1 -k2,2n)
  if [[ -n "$ROWS" ]]; then
    summary "### Findings by MASVS category"
    summary ""
    summary "| MASVS Category | MASWE | Severity | Finding |"
    summary "|:--------------|:------|:---------|:--------|"
    while IFS="$(printf '\t')" read -r cat _rank sev maswe title; do
      [[ -z "$cat" ]] && continue
      if [[ -n "$maswe" && "$maswe" == MASWE-* ]]; then
        maswe_cell="<a href=\"https://mas.owasp.org/MASWE/$cat/$maswe/\" target=\"_blank\" rel=\"noopener\">$maswe</a>"
      else
        maswe_cell="—"
      fi
      summary "| $cat | $maswe_cell | $sev | $title |"
    done <<< "$ROWS"
    summary ""
  fi
fi

DETAILS_URL="${BASE_URL}/dashboard/scans/${PROJECT_NAME}"
summary "📄 <a href=\"$REPORT_URL\" target=\"_blank\" rel=\"noopener\">View full report</a> · 🔎 <a href=\"$DETAILS_URL\" target=\"_blank\" rel=\"noopener\">Scan details</a>"

# ── 8. gate the build ────────────────────────────────────────────────────────
header "Gate (--fail-on $FAIL_ON)"
BLOCKING=0
case "$FAIL_ON" in
  critical) BLOCKING=$CRITICAL;;
  high)     BLOCKING=$((CRITICAL + HIGH));;
  medium)   BLOCKING=$((CRITICAL + HIGH + MEDIUM));;
  low)      BLOCKING=$((CRITICAL + HIGH + MEDIUM + LOW));;
  none)     BLOCKING=0;;
esac

if [[ "$FAIL_ON" != "none" && "$BLOCKING" -gt 0 ]]; then
  summary ""
  summary "> ❌ **Build failed:** $BLOCKING finding(s) at or above \`$FAIL_ON\`."
  echo -e "\n  ${RED}✗ $BLOCKING finding(s) at or above '$FAIL_ON' — failing the build.${RESET}\n"
  exit 1
fi

echo -e "\n  ${GREEN}✓ No findings at or above '$FAIL_ON' — build passes.${RESET}\n"
