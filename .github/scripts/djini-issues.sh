#!/usr/bin/env bash
#
# djini-issues.sh — open a GitHub issue per djini finding (from the SARIF).
#
# Optional: enable it with the workflow's `create_issues` input. Native GitHub
# Code Scanning alerts (the upload-sarif step) are the recommended path; this is
# for teams that track security work as issues. De-duplicates by title so re-runs
# don't spam. Requires: gh, jq, and a token with `issues: write`.
#
# Usage: djini-issues.sh [sarif=djini-results.sarif]
#   env: GH_TOKEN (required), GITHUB_REPOSITORY (required), FAIL_ON (min severity)
#
set -euo pipefail

SARIF="${1:-djini-results.sarif}"
MIN_SEV="${FAIL_ON:-high}"   # only file issues at/above this severity
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY not set}"

[[ -f "$SARIF" ]] || { echo "No SARIF at $SARIF — nothing to file."; exit 0; }
command -v gh >/dev/null 2>&1 || { echo "gh CLI not available — skipping."; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "jq not available — skipping."; exit 0; }

_rank() { case "$1" in Critical) echo 4;; High) echo 3;; Medium) echo 2;; Low) echo 1;; *) echo 0;; esac; }
case "$MIN_SEV" in
  critical) MIN=4;; high) MIN=3;; medium) MIN=2;; low) MIN=1;; none) MIN=99;; *) MIN=3;;
esac
[[ "$MIN" -ge 99 ]] && { echo "FAIL_ON=none — not filing issues."; exit 0; }

# Ensure the label exists (ignore if it already does).
gh label create djini --repo "$REPO" --color 5319e7 --description "Djini.AI security finding" 2>/dev/null || true

count=0
while read -r r; do
  [[ -z "$r" ]] && continue
  sev=$(jq -r '.properties.severity // "Unknown"' <<<"$r")
  [[ "$(_rank "$sev")" -lt "$MIN" ]] && continue
  maswe=$(jq -r '.ruleId // "DJINI"' <<<"$r")
  msg=$(jq -r '.message.text // "Security finding"' <<<"$r")
  short=$(printf '%s' "$msg" | cut -d'—' -f1 | sed 's/[[:space:]]*$//')
  file=$(jq -r '.locations[0].physicalLocation.artifactLocation.uri // "?"' <<<"$r")
  line=$(jq -r '.locations[0].physicalLocation.region.startLine // 0' <<<"$r")
  masvs=$(jq -r '.properties.masvs // ""' <<<"$r")
  rem=$(jq -r '.properties.remediation // ""' <<<"$r")

  title="[Djini][$sev] $short ($maswe)"
  # De-dup: skip if an open issue with this exact title already exists.
  if gh issue list --repo "$REPO" --label djini --state open --search "in:title \"$title\"" \
       --json title --jq '.[].title' 2>/dev/null | grep -Fxq "$title"; then
    echo "  exists: $title"
    continue
  fi

  body=$(cat <<EOB
**Severity:** $sev
**MASWE:** [$maswe](https://mas.owasp.org/MASWE/$maswe/)${masvs:+ · **MASVS:** $masvs}
**Location:** \`$file:$line\`

$msg
${rem:+
**Remediation:** $rem}

<sub>Filed automatically by Djini.AI Security Scan.</sub>
EOB
)
  if gh issue create --repo "$REPO" --title "$title" --label djini --body "$body" >/dev/null 2>&1; then
    echo "  created: $title"
    count=$((count + 1))
  else
    echo "  failed to create: $title"
  fi
done < <(jq -c '.runs[].results[]?' "$SARIF")

echo "djini-issues: done."
