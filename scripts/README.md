# Maintainer scripts

These scripts submit this plugin to the
[awesome-dsh-plugin](https://github.com/awesome-dsh-plugin/awesome-dsh-plugin)
registry. They are maintainer tooling; installing the plugin does not need them.

## `submit-to-market.sh`

Adds `data/plugins/anonamerjaxon-dev__dsh-model-grid.yml` to a fork and opens a
pull request. It is idempotent: it exits early if the entry is already upstream
or a PR from the same branch is already open.

```sh
scripts/submit-to-market.sh --dry-run   # validate everything, change nothing
scripts/submit-to-market.sh             # open the PR
```

The registry's CI rejects repositories younger than **1 day**, so the script
exits `75` until the repo's `created_at` is at least 24 h old (+10 min buffer).
`--skip-age-check` bypasses that guard for testing only.

Requirements: `gh` (authenticated), `jq`, `python3`.

## `schedule-submit.sh`

Installs a one-shot launchd agent (`com.jackson.dsh-model-grid-submit`) that runs
`submit-to-market.sh` at the first moment the registry will accept the repo —
`created_at + 24 h + 15 min`, in local time.

```sh
scripts/schedule-submit.sh              # install / refresh the timer
scripts/schedule-submit.sh --dry-run    # print the plist, install nothing
scripts/schedule-submit.sh --uninstall  # remove the timer
```

The job logs to `~/Library/Logs/dsh-model-grid-submit.log`. launchd runs a
calendar job that was missed while the Mac slept once it wakes.

> **macOS TCC note.** launchd's `/bin/bash` cannot read files under
> `~/Documents`, `~/Desktop` or `~/Downloads` (`Operation not permitted`). That
> is why the installer copies the submit script to
> `~/.dsh/bin/dsh-model-grid-submit.sh` and points the job there.
