#!/usr/bin/env bash
#
# Submit dsh-model-grid to the awesome-dsh-plugin registry.
#
# The registry (https://github.com/awesome-dsh-plugin/awesome-dsh-plugin)
# accepts one YAML file per plugin at data/plugins/<owner>__<repo>.yml, via a
# pull request. Its CI rejects repos younger than 1 day, so this script refuses
# to run before that bar unless --skip-age-check is passed (testing only).
#
# Idempotent: if the entry is already upstream, or a PR from the same branch is
# already open, it exits 0 without touching anything.
#
# Usage:
#   scripts/submit-to-market.sh            # submit (or report why not)
#   scripts/submit-to-market.sh --dry-run  # check everything, change nothing
#   scripts/submit-to-market.sh --skip-age-check
#
set -euo pipefail

OWNER="anonamerjaxon-dev"
REPO="dsh-model-grid"
UPSTREAM="awesome-dsh-plugin/awesome-dsh-plugin"
FORK="$OWNER/awesome-dsh-plugin"
BRANCH="add-dsh-model-grid"
ENTRY="data/plugins/${OWNER}__${REPO}.yml"
TARBALL="https://github.com/${OWNER}/${REPO}/releases/latest/download/${REPO}-1.0.0.tgz"
AGE_SECONDS=86400
AGE_BUFFER=600
LOG_PREFIX="[dsh-model-grid submit]"

DRY_RUN=0
SKIP_AGE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --skip-age-check) SKIP_AGE=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 64 ;;
  esac
done

log() { printf '%s %s %s\n' "$(date '+%Y-%m-%d %H:%M:%S%z')" "$LOG_PREFIX" "$*"; }
die() { log "ERROR: $*"; exit 1; }
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    log "DRY-RUN would run: $*"
    return 0
  fi
  "$@"
}

command -v gh >/dev/null 2>&1 || die "gh CLI not found in PATH"
command -v jq >/dev/null 2>&1 || die "jq not found in PATH"
command -v python3 >/dev/null 2>&1 || die "python3 not found in PATH"
gh auth status >/dev/null 2>&1 || die "gh is not authenticated"

# ---------------------------------------------------------------- prerequisites
log "checking ${OWNER}/${REPO}"
repo_json=$(gh api "repos/${OWNER}/${REPO}") || die "cannot read the plugin repo"

created=$(printf '%s' "$repo_json" | jq -r .created_at)
topics=$(printf '%s' "$repo_json" | jq -r '.topics // [] | join(",")')
case ",$topics," in
  *,dsh-plugin,*) ;;
  *) die "repo is missing the required 'dsh-plugin' topic" ;;
esac

manifest=$(gh api "repos/${OWNER}/${REPO}/contents/package.json" --jq .content \
  | base64 -d | jq -e '.dsh.bundle.patch' 2>/dev/null || true)
[ -n "$manifest" ] || die "package.json is missing dsh.bundle.patch"

if [ "$SKIP_AGE" -eq 0 ]; then
  created_epoch=$(python3 - "$created" <<'PY'
import datetime, sys
print(int(datetime.datetime.strptime(sys.argv[1], "%Y-%m-%dT%H:%M:%SZ")
          .replace(tzinfo=datetime.timezone.utc).timestamp()))
PY
)
  now=$(date +%s)
  earliest=$((created_epoch + AGE_SECONDS + AGE_BUFFER))
  if [ "$now" -lt "$earliest" ]; then
    log "repo is younger than 1 day (created ${created}); earliest submit $(python3 - "$earliest" <<'PY'
import datetime, sys
print(datetime.datetime.fromtimestamp(int(sys.argv[1])).strftime("%Y-%m-%d %H:%M:%S %Z"))
PY
)"
    exit 75
  fi
fi

# ---------------------------------------------------------------- idempotency
if gh api "repos/${UPSTREAM}/contents/${ENTRY}" >/dev/null 2>&1; then
  log "already listed upstream at ${ENTRY}; nothing to do"
  exit 0
fi

existing_pr=$(gh pr list --repo "$UPSTREAM" --head "${OWNER}:${BRANCH}" \
  --state open --json number --jq '.[0].number // empty')
if [ -n "$existing_pr" ]; then
  log "PR #${existing_pr} is already open; nothing to do"
  exit 0
fi

# ---------------------------------------------------------------- the entry
entry_yaml=$(cat <<YAML
url: https://github.com/${OWNER}/${REPO}
name: ${OWNER}/${REPO}
category: ui
tarball: ${TARBALL}
description:
  en: 'Responsive card grid for the DeepSeek Harness composer model picker, grouped by provider. Host-only: injects a stylesheet through webserver/index-inject without rebuilding the client bundle, and supports both the stock picker and the dsh-peakrate menu.'
  zh: '把 DeepSeek Harness 输入框的模型选择器改成按供应商分组的响应式卡片网格。纯宿主端：通过 webserver/index-inject 注入样式、无需重建前端包，同时支持官方选择器与 dsh-peakrate 菜单。'
YAML
)

if [ "$DRY_RUN" -eq 1 ]; then
  log "DRY-RUN: would write ${ENTRY} to ${FORK}:${BRANCH} and open a PR against ${UPSTREAM}:main"
  printf '%s\n' "$entry_yaml"
  exit 0
fi

# ---------------------------------------------------------------- ensure fork
if ! gh api "repos/${FORK}" >/dev/null 2>&1; then
  log "forking ${UPSTREAM} -> ${FORK}"
  gh repo fork "$UPSTREAM" --clone=false
fi
gh api "repos/${FORK}" >/dev/null 2>&1 || die "fork ${FORK} is not available"

# ---------------------------------------------------------------- branch + file
base_sha=$(gh api "repos/${UPSTREAM}/git/ref/heads/main" --jq .object.sha)
log "upstream main is ${base_sha}"

if gh api "repos/${FORK}/git/ref/heads/${BRANCH}" >/dev/null 2>&1; then
  gh api -X PATCH "repos/${FORK}/git/refs/heads/${BRANCH}" \
    -F sha="$base_sha" -F force=true >/dev/null
else
  gh api -X POST "repos/${FORK}/git/refs" \
    -f ref="refs/heads/${BRANCH}" -f sha="$base_sha" >/dev/null
fi

content_b64=$(printf '%s\n' "$entry_yaml" | base64 | tr -d '\n')
file_sha=$(gh api "repos/${FORK}/contents/${ENTRY}?ref=${BRANCH}" --jq .sha 2>/dev/null || true)

put_args=(-X PUT "repos/${FORK}/contents/${ENTRY}"
  -f message="Add ${OWNER}/${REPO}"
  -f content="$content_b64"
  -f branch="$BRANCH")
[ -n "$file_sha" ] && put_args+=(-f sha="$file_sha")
gh api "${put_args[@]}" >/dev/null
log "wrote ${ENTRY} on ${FORK}:${BRANCH}"

# ---------------------------------------------------------------- pull request
pr_body=$(cat <<BODY
Adds \`${OWNER}/${REPO}\` to the registry.

- Repo: https://github.com/${OWNER}/${REPO}
- Category: \`ui\` (composer model-picker layout)
- Manifest: \`dsh.bundle.patch\` present; \`dsh-plugin\` topic set
- Prebuilt tarball attached to the latest GitHub release

The plugin turns the model picker in the DSH composer into a responsive card
grid grouped by provider. It is host-only: it appends a \`<style>\` through
\`webserver/index-inject\` on every index response, so no client bundle is
rebuilt. It styles both the stock \`dsh-client-ui-model-selection\` dropdown
and the \`dsh-peakrate\` menu when that plugin is installed.
BODY
)

log "opening pull request against ${UPSTREAM}"
pr_url=$(gh pr create --repo "$UPSTREAM" \
  --head "${OWNER}:${BRANCH}" --base main \
  --title "Add ${OWNER}/${REPO}" \
  --body "$pr_body")
log "opened ${pr_url}"
