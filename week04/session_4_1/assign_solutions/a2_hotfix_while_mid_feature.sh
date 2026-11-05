#!/usr/bin/env bash
# a2_hotfix_while_mid_feature.sh -- Session 4.1 Assignments Solutions (trainer copy): Assignment 2: an urgent fix while you are mid-feature
# Replays the assignment in a throwaway folder; your repository is not changed.
# Run from anywhere inside pharmaflow-ai:
#   bash week04/session_4_1/assign_solutions/a2_hotfix_while_mid_feature.sh
# The lines after "=== CHECK" must match expected_output/a2_hotfix_while_mid_feature.txt.
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
need_on_main "$LIB" week03/session_3_1/run_query.py \
    data/raw/adverse_events_10k.csv README.md
[ -f "$HELPER" ] || {
    echo "Cannot replay: put practice_team.sh in week04/session_4_1/"; exit 2; }
grep -q '^a1)' "$HELPER" || {
    echo "Cannot replay: replace week04/session_4_1/practice_team.sh with the"
    echo "Assignments version (it has the a1, a2 and a3 commands)."; exit 2; }
export PRACTICE_DIR="$WORK/practice"
run 'bash "$HELPER" setup'
[ -d "$PRACTICE_DIR/you" ] || {
    echo "Cannot replay: practice_team.sh setup failed (see above)."; exit 2; }
cd "$PRACTICE_DIR/you"

run 'git switch -c feature/first-report-date'
edit "$LIB" '       COUNT(*) AS reports,
' '       COUNT(*) AS reports,
       MIN(report_date) AS first_report,
'
run 'bash "$HELPER" a2'
run 'git status --short'
echo "## Park the unfinished work on its own branch first"
run 'git commit -am "WIP: first report date per drug (not checked yet)"'
run 'git switch main'
run 'git status --short'
run 'git pull'
edit "$LIB" '--            (Week 2).
' '--            (Week 2).
--            Counts are reports, not patients.
'
run 'git diff'
run 'git commit -am "Header: counts are reports, not patients"'
run 'git push'
echo "## Back to the feature: bring the fix in"
run 'git switch feature/first-report-date'
run 'git merge --no-edit main'
run 'python3 week03/session_3_1/run_query.py week04/session_4_1/top10_drugs.sql'
run 'git status --short'
run 'git restore week04/session_4_1/top10_drugs.parquet'
run 'git push -u origin feature/first-report-date'
run 'git log --graph --oneline -6'
run 'bash "$HELPER" check-a2'
echo "=== CHECK"
echo "-- GitHub main, latest two"; git log --format=%s -2 origin/main
echo "-- the fix commit"; git show --format= --stat origin/main | tail -1
echo "-- feature branch, first parents"
git log --first-parent --format=%s -2 origin/feature/first-report-date
bash "$HELPER" check-a2
