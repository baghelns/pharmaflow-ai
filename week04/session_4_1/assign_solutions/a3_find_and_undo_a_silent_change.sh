#!/usr/bin/env bash
# a3_find_and_undo_a_silent_change.sh -- Session 4.1 Assignments Solutions (trainer copy): Assignment 3: find and undo a silent change
# Replays the assignment in a throwaway folder; your repository is not changed.
# Run from anywhere inside pharmaflow-ai:
#   bash week04/session_4_1/assign_solutions/a3_find_and_undo_a_silent_change.sh
# The lines after "=== CHECK" must match expected_output/a3_find_and_undo_a_silent_change.txt.
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

run 'bash "$HELPER" a3'
run 'git fetch'
run 'git log --oneline safety-pack-w46..origin/main'
run 'git log --oneline safety-pack-w46..origin/main -- week04/session_4_1/top10_drugs.sql'
echo "## Run every version of the file since the tag"
cat > "$WORK/versions.sh" <<'SH'
L=week04/session_4_1/top10_drugs.sql
for c in safety-pack-w46 $(git rev-list --reverse safety-pack-w46..origin/main -- $L); do
    git show $c:$L > /tmp/version.sql
    out=$(python3 week03/session_3_1/run_query.py /tmp/version.sql)
    echo "$(git log --format=%s -1 $c)"
    echo "   $(grep DUPIXENT <<< "$out" | tr -s ' ')" \
         " HUMIRA rows: $(grep -c HUMIRA <<< "$out")"
done
SH
sed -i "s|/tmp/version.sql|$WORK/version.sql|" "$WORK/versions.sh"
run 'bash "$WORK/versions.sh"'
CHANGE=$(git log --format=%h -1 --grep='^events view: skip incomplete rows$' origin/main)
run "git show --format='%h %an: %s' $CHANGE"
echo "## How much the change moves the answer"
run 'git show safety-pack-w46:week04/session_4_1/top10_drugs.sql > "$WORK/monday.sql"'
run 'git show origin/main:week04/session_4_1/top10_drugs.sql > "$WORK/today.sql"'
run 'python3 week03/session_3_1/run_query.py "$WORK/monday.sql" > "$WORK/monday.txt"'
run 'python3 week03/session_3_1/run_query.py "$WORK/today.sql" > "$WORK/today.txt"'
run 'diff "$WORK/monday.txt" "$WORK/today.txt"'
cat > "$WORK/dropped.sql" <<'SQL'
SELECT COUNT(*) AS all_reports,
       COUNT(*) FILTER (WHERE country IS NULL) AS no_country,
       COUNT(*) FILTER (WHERE serious IS NULL) AS no_serious_code,
       COUNT(*) FILTER (WHERE country IS NULL OR serious IS NULL) AS skipped
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'serious': 'VARCHAR'});
SQL
run 'cat "$WORK/dropped.sql"'
run 'python3 week03/session_3_1/run_query.py "$WORK/dropped.sql"'
echo "## Undo only that commit"
run 'git status --short'
run 'git merge origin/main'
run "git revert $CHANGE"
run 'git status --short'
run 'sed -n 17,40p week04/session_4_1/top10_drugs.sql'
edit "$LIB" 're:<<<<<<< HEAD\n(.*?)\)\nWHERE country IS NOT NULL\n  AND serious IS NOT NULL;\n=======\n.*?>>>>>>> [^\n]*\n' '\1);
'
run 'sed -n 17,30p week04/session_4_1/top10_drugs.sql'
run 'git diff --check && echo "no conflict markers left"'
run 'python3 week03/session_3_1/run_query.py week04/session_4_1/top10_drugs.sql'
run 'git add week04/session_4_1/top10_drugs.sql'
run 'git revert --continue --no-edit'
run 'git status --short'
run 'git push'
run 'bash "$HELPER" check-a3'
echo "=== CHECK"
echo "-- latest five on GitHub main"; git log --format=%s -5 origin/main
echo "-- the answer on GitHub main"
git show origin/main:"$LIB" > "$WORK/final.sql"
python3 week03/session_3_1/run_query.py "$WORK/final.sql" | grep -E "DUPIXENT|HUMIRA|rows"
bash "$HELPER" check-a3
