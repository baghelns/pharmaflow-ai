#!/usr/bin/env bash
# 02_ex1_history_and_restore.sh -- Session 4.1 Git Solutions (trainer copy): Exercise 1: read the history, get a file back
# Replays the exercise in a throwaway folder; your repository is not changed.
# Run from anywhere inside pharmaflow-ai:
#   bash week04/session_4_1/git_solutions/02_ex1_history_and_restore.sh
# The lines after "=== CHECK" must match expected_output/02_ex1_history_and_restore.txt.
set -euo pipefail
REPO=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
case "$REPO" in */week04/session_4_1/practice/*) REPO=${REPO%/week04/session_4_1/practice/*} ;; esac
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
# A private Git configuration, so your own settings cannot change the replay.
export GIT_CONFIG_GLOBAL="$WORK/gitconfig" GIT_CONFIG_NOSYSTEM=1
git config --global user.name "Trainer Replay"
git config --global user.email "replay@elevox.example"
git config --global init.defaultBranch main
LIB=week04/session_4_1/top10_drugs.sql
HELPER="$REPO/week04/session_4_1/practice_team.sh"

# run '<command>': print it, run it, print its output with commit IDs and
# the throwaway folder's path masked (they differ on every run).
run() {
    echo "\$ $1" | sed -E 's/\b[0-9a-f]{7,40}\b/<id>/g'
    set +e; ( eval "$1" ) > "$WORK/.out" 2>&1; local rc=$?; set -e
    sed -E -e "s|$WORK|<work>|g" -e 's/\b[0-9a-f]{7,40}\b/<id>/g' "$WORK/.out"
    [ "$rc" -eq 0 ] || echo "(exit code $rc)"
    echo
}
# edit '<file>' '<old text>' '<new text>': what you do in the editor.
edit() {
    python3 - "$1" "$2" "$3" <<'PY'
import re, sys
path, old, new = sys.argv[1:4]
text = open(path, encoding="utf-8").read()
if old.startswith("re:"):
    text, n = re.subn(old[3:], new, text, flags=re.S)
else:
    n = text.count(old)
    text = text.replace(old, new)
if n != 1:
    sys.exit(f"edit: expected 1 match in {path}, found {n}")
open(path, "w", encoding="utf-8").write(text)
PY
    echo "(edited $1 in the editor)"
    echo
}
# The replay copies your committed main branch: stop early, with a clear
# message, if a file it needs is not there.
need_on_main() {
    local f missing=0
    for f in "$@"; do
        git -C "$REPO" cat-file -e "main:$f" 2>/dev/null ||
            { echo "Cannot replay: $f is not committed on main."; missing=1; }
    done
    [ "$missing" = 0 ] || exit 2
}
need_on_main "$LIB" week03/session_3_1/run_query.py data/raw/adverse_events_10k.csv
git clone -q "$REPO" "$WORK/pharmaflow-ai" && cd "$WORK/pharmaflow-ai"
run 'git log --oneline -3 -- week04/session_4_1/top10_drugs.sql'
run 'rm week04/session_4_1/top10_drugs.sql'
run 'git status --short'
run 'python3 week03/session_3_1/run_query.py week04/session_4_1/top10_drugs.sql'
run 'git restore week04/session_4_1/top10_drugs.sql'
run 'git status --short'
echo "## Part B: an accidental edit"
edit "$LIB" 'LIMIT 10;' 'LIMIT 100;'
run 'git diff --stat'
run 'git diff'
run 'git restore week04/session_4_1/top10_drugs.sql'
run 'python3 week03/session_3_1/run_query.py week04/session_4_1/top10_drugs.sql'
echo "=== CHECK"
echo "-- status"; [ -z "$(git status --short)" ] && echo "(clean)" || git status --short
echo "-- first and last row, row count"
python3 week03/session_3_1/run_query.py "$LIB" | grep -E "DUPIXENT|VICTOZA|rows"
