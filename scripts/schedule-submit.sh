#!/usr/bin/env bash
#
# Install a one-shot launchd agent that runs submit-to-market.sh at the first
# moment the awesome-dsh-plugin registry will accept the repo (created_at + 24h
# + 15 min buffer).
#
# Usage:
#   scripts/schedule-submit.sh              # install/refresh the timer
#   scripts/schedule-submit.sh --uninstall  # remove it
#   scripts/schedule-submit.sh --dry-run    # print the plist, install nothing
#
set -euo pipefail

OWNER="anonamerjaxon-dev"
REPO="dsh-model-grid"
LABEL="com.jackson.dsh-model-grid-submit"
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/submit-to-market.sh"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/dsh-model-grid-submit.log"
DOMAIN="gui/$(id -u)"

DRY_RUN=0
UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --uninstall) UNINSTALL=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 64 ;;
  esac
done

if [ "$UNINSTALL" -eq 1 ]; then
  launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "removed $LABEL"
  exit 0
fi

[ -x "$SCRIPT" ] || { echo "submit script is not executable: $SCRIPT" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "gh not found" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 not found" >&2; exit 1; }

created=$(gh api "repos/$OWNER/$REPO" --jq .created_at)
read -r YEAR MONTH DAY HOUR MINUTE < <(python3 - "$created" <<'PY'
import datetime, sys
created = datetime.datetime.strptime(sys.argv[1], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc)
fire = created + datetime.timedelta(seconds=86400 + 900)  # 24h + 15 min
local = fire.astimezone()
print(local.year, local.month, local.day, local.hour, local.minute)
PY
)

echo "repo created:   $created"
echo "timer fires:    $YEAR-$MONTH-$DAY $(printf '%02d:%02d' "$HOUR" "$MINUTE") (local)"

PLIST_XML=$(cat <<XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SCRIPT</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Year</key><integer>$YEAR</integer>
    <key>Month</key><integer>$MONTH</integer>
    <key>Day</key><integer>$DAY</integer>
    <key>Hour</key><integer>$HOUR</integer>
    <key>Minute</key><integer>$MINUTE</integer>
  </dict>
  <key>RunAtLoad</key>
  <false/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>$HOME</string>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/Users/jackson/.nvm/versions/node/v22.21.1/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>StandardOutPath</key>
  <string>$LOG</string>
  <key>StandardErrorPath</key>
  <string>$LOG</string>
</dict>
</plist>
XML
)

if [ "$DRY_RUN" -eq 1 ]; then
  printf '%s\n' "$PLIST_XML"
  exit 0
fi

mkdir -p "$(dirname "$PLIST")" "$(dirname "$LOG")"
printf '%s\n' "$PLIST_XML" > "$PLIST"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"
echo "installed: $PLIST"
echo "log:       $LOG"
echo "cancel:    $0 --uninstall"
launchctl print "$DOMAIN/$LABEL" 2>/dev/null | grep -E "state|next fire|program|runs" | head -6 || true
