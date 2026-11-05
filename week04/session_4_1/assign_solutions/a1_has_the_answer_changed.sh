#!/usr/bin/env bash
# a1_has_the_answer_changed.sh -- Session 4.1 Assignments Solutions (trainer copy): Assignment 1: has the answer we sent changed?
# Replays the assignment in a throwaway folder; your repository is not changed.
# Run from anywhere inside pharmaflow-ai:
#   bash week04/session_4_1/assign_solutions/a1_has_the_answer_changed.sh
# The lines after "=== CHECK" must match expected_output/a1_has_the_answer_changed.txt.
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

run 'bash "$HELPER" a1'
run 'git fetch'
run 'git tag'
run 'git log --oneline safety-pack-w45..origin/main'
run 'git log --format="%h %an: %s" safety-pack-w45..origin/main -- week04/session_4_1/top10_drugs.sql'
run 'git diff safety-pack-w45 origin/main -- week04/session_4_1/top10_drugs.sql'
run 'git show safety-pack-w45:week04/session_4_1/top10_drugs.sql > "$WORK/sent.sql"'
run 'git show origin/main:week04/session_4_1/top10_drugs.sql > "$WORK/now.sql"'
run 'python3 week03/session_3_1/run_query.py "$WORK/sent.sql" > "$WORK/sent.txt"'
run 'python3 week03/session_3_1/run_query.py "$WORK/now.sql" > "$WORK/now.txt"'
run 'diff "$WORK/sent.txt" "$WORK/now.txt" && echo "same answer"'
run 'cat "$WORK/now.txt"'
run 'git status --short'
echo "=== CHECK"
echo "-- commits since the tag that touch the file"
git log --format="%an: %s" safety-pack-w45..origin/main -- "$LIB"
echo "-- lines changed in the file"
git diff --stat safety-pack-w45 origin/main -- "$LIB" | tail -1
echo "-- the two answers"
diff "$WORK/sent.txt" "$WORK/now.txt" >/dev/null && echo "identical"
grep -E "DUPIXENT|VICTOZA|rows" "$WORK/now.txt"
