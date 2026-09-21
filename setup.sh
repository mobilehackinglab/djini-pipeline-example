#!/usr/bin/env bash
#
# setup.sh — one-time wizard for wiring djini into this repo's CI.
#
# Run this once after creating your repo from this template (or after cloning
# it directly). It trims the repo down to the platform(s) you actually need,
# and wires the two things djini needs in GitHub Actions: a DJINI_BASE_URL
# repo variable and a DJINI_API_KEY repo secret.
#
#   ./setup.sh                    interactive — asks you everything
#   ./setup.sh --yes ...          non-interactive (for scripting), e.g.:
#     ./setup.sh --yes --platform android --base-url https://app.djini.ai \
#                --api-key "$DJINI_API_KEY" --strip-samples
#
# Flags:
#   --platform android|ios|both     which workflow(s)/sample app(s) to keep
#   --base-url URL                  your djini instance
#   --api-key KEY                   your djini API key (or set DJINI_API_KEY env)
#   --keep-samples / --strip-samples  keep the bundled demo app(s), or delete
#                                    them so you can wire your own build
#   --yes                           don't prompt; require the flags above
#   -h, --help
#
set -euo pipefail

BOLD='\033[1m'; DIM='\033[2m'; GREEN='\033[32m'; YELLOW='\033[33m'; RESET='\033[0m'
[[ -t 1 ]] || { BOLD=''; DIM=''; GREEN=''; YELLOW=''; RESET=''; }

header() { echo -e "\n${BOLD}== $1 ==${RESET}"; }
die()    { echo "ERROR: $*" >&2; exit 1; }

PLATFORM=""
BASE_URL=""
API_KEY="${DJINI_API_KEY:-}"
SAMPLES=""     # "keep" | "strip"
NON_INTERACTIVE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)       PLATFORM="$2";        shift 2;;
    --base-url)       BASE_URL="$2";        shift 2;;
    --api-key)        API_KEY="$2";         shift 2;;
    --keep-samples)   SAMPLES="keep";       shift;;
    --strip-samples)  SAMPLES="strip";      shift;;
    --yes)            NON_INTERACTIVE=1;    shift;;
    -h|--help)
      grep -E '^#( |$)' "$0" | sed -E 's/^# ?//'; exit 0;;
    *) die "Unknown option: $1 (see --help)";;
  esac
done

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
[[ -d .github/workflows ]] || die "Run this from the root of a djini-pipeline-example checkout."

echo -e "${BOLD}Djini CI setup wizard${RESET}"
echo "This configures the djini scan workflow(s) in this repo."

# ── 1. platform ────────────────────────────────────────────────────────────
if [[ -z "$PLATFORM" ]]; then
  [[ -n "$NON_INTERACTIVE" ]] && die "--platform is required with --yes"
  header "1. Which platform(s) do you want to scan?"
  echo "  1) Android only"
  echo "  2) iOS only"
  echo "  3) Both"
  read -rp "Choice [3]: " choice
  case "${choice:-3}" in
    1) PLATFORM="android";;
    2) PLATFORM="ios";;
    *) PLATFORM="both";;
  esac
fi
case "$PLATFORM" in
  android|ios|both) ;;
  *) die "--platform must be android, ios, or both";;
esac

# ── 2. base URL ──────────────────────────────────────────────────────────────
if [[ -z "$BASE_URL" ]]; then
  [[ -n "$NON_INTERACTIVE" ]] && die "--base-url is required with --yes"
  header "2. Your djini instance URL"
  read -rp "djini base URL [https://app.djini.ai]: " BASE_URL
  BASE_URL="${BASE_URL:-https://app.djini.ai}"
fi
BASE_URL="${BASE_URL%/}"

# ── 3. API key ────────────────────────────────────────────────────────────────
if [[ -z "$API_KEY" ]]; then
  [[ -n "$NON_INTERACTIVE" ]] && die "--api-key (or \$DJINI_API_KEY) is required with --yes"
  header "3. Your djini API key"
  echo -e "${DIM}Get one from djini -> Settings -> API key. Input is hidden.${RESET}"
  read -rsp "API key: " API_KEY; echo
fi
[[ -n "$API_KEY" ]] || die "No API key provided."

# ── 4. bundled sample apps ────────────────────────────────────────────────────
if [[ -z "$SAMPLES" ]]; then
  if [[ -n "$NON_INTERACTIVE" ]]; then
    SAMPLES="keep"
  else
    header "4. Bundled sample app(s)"
    echo "This template ships a small vulnerable lab app per platform so the"
    echo "pipeline runs end-to-end out of the box."
    echo "  1) Keep it/them — try djini against the sample app(s) first"
    echo "  2) Remove — I'll wire this workflow to build/upload my own app"
    read -rp "Choice [1]: " choice
    [[ "${choice:-1}" == "2" ]] && SAMPLES="strip" || SAMPLES="keep"
  fi
fi

# ── apply: trim to the chosen platform(s) ─────────────────────────────────────
header "Applying changes"

# Remove a platform ENTIRELY (its workflow + its sample app) — used for the
# platform(s) the user didn't choose, regardless of --keep-samples/--strip.
remove_unused_platform() {
  local wf="$1" sample_dir="$2"
  if [[ -f "$wf" ]]; then
    git rm -q -f "$wf" 2>/dev/null || rm -f "$wf"
    echo "  removed $wf"
  fi
  if [[ -d "$sample_dir" ]]; then
    git rm -q -rf "$sample_dir" 2>/dev/null || rm -rf "$sample_dir"
    echo "  removed $sample_dir/"
  fi
}

# Remove just the sample app for a platform the user IS keeping — only when
# they asked to strip samples (they're wiring their own build).
strip_sample() {
  local sample_dir="$1"
  if [[ -d "$sample_dir" ]]; then
    git rm -q -rf "$sample_dir" 2>/dev/null || rm -rf "$sample_dir"
    echo "  removed $sample_dir/"
  fi
}

case "$PLATFORM" in
  android)
    remove_unused_platform .github/workflows/djini-ios.yml sample-app-ios
    [[ "$SAMPLES" == "strip" ]] && strip_sample sample-app-android
    ;;
  ios)
    remove_unused_platform .github/workflows/djini-android.yml sample-app-android
    [[ "$SAMPLES" == "strip" ]] && strip_sample sample-app-ios
    ;;
  both)
    if [[ "$SAMPLES" == "strip" ]]; then
      strip_sample sample-app-android
      strip_sample sample-app-ios
    fi
    ;;
esac

if [[ "$SAMPLES" == "strip" ]]; then
  echo -e "${YELLOW}  Note: the workflow's build step still points at the sample app's"
  echo -e "  APK/IPA path — it will fail fast with a clear error until you edit it"
  echo -e "  to build/produce your own artifact and set steps.build.outputs.artifact.${RESET}"
fi

# ── wire the repo secret + variable ───────────────────────────────────────────
header "Wiring GitHub secrets"

REPO=""
if command -v gh >/dev/null 2>&1; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
fi

if [[ -n "$REPO" ]] && gh auth status >/dev/null 2>&1; then
  gh variable set DJINI_BASE_URL --repo "$REPO" --body "$BASE_URL"
  echo "  set variable DJINI_BASE_URL = $BASE_URL"
  printf '%s' "$API_KEY" | gh secret set DJINI_API_KEY --repo "$REPO"
  echo -e "  ${GREEN}set secret DJINI_API_KEY${RESET} (value hidden)"
else
  echo -e "${YELLOW}  'gh' CLI not found or not authenticated — set these manually:${RESET}"
  echo "    gh variable set DJINI_BASE_URL --body '$BASE_URL'"
  echo "    gh secret set DJINI_API_KEY --body '<your key>'"
  echo "  or via GitHub: Settings -> Secrets and variables -> Actions"
  REPO="<your-org>/<your-repo>"
fi

# ── commit the trim (if anything changed and we're in a git repo) ────────────
if git rev-parse --git-dir >/dev/null 2>&1 && ! git diff --cached --quiet 2>/dev/null; then
  header "Committing changes"
  git commit -q -m "Configure djini CI for ${PLATFORM} (via setup.sh)"
  echo "  committed. Push when ready: git push"
fi

# ── done ───────────────────────────────────────────────────────────────────
header "Done"
echo "Next: GitHub -> $REPO -> Actions -> \"Djini.AI Security Scan\" -> Run workflow."
echo -e "${DIM}(Re-run this script any time to rotate the API key or reconfigure.)${RESET}"
