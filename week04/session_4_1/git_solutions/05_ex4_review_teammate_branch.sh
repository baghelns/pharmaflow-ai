#!/usr/bin/env bash
# 05_ex4_review_teammate_branch.sh -- Session 4.1 Git Solutions (trainer copy): Exercise 4: review a teammate's branch
# Replays the exercise in a throwaway folder; your repository is not changed.
# Run from anywhere inside pharmaflow-ai:
#   bash week04/session_4_1/git_solutions/05_ex4_review_teammate_branch.sh
# The lines after "=== CHECK" must match expected_output/05_ex4_review_teammate_branch.txt.
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
[ -f "$HELPER" ] || { echo "Cannot replay: put practice_team.sh in week04/session_4_1/"; exit 2; }
export PRACTICE_DIR="$WORK/practice"
run 'bash "$HELPER" setup'
[ -d "$PRACTICE_DIR/you" ] || { echo "Cannot replay: practice_team.sh setup failed (see above)."; exit 2; }
cd "$PRACTICE_DIR/you"
run 'bash "$HELPER" ex4'
run 'git fetch'
run 'git branch -r'
run 'git log --oneline main..origin/feature/top10-serious-share'
run 'git diff main...origin/feature/top10-serious-share'
run 'git show origin/feature/top10-serious-share:week04/session_4_1/top10_drugs.sql > "$WORK/review_03.sql"'
run 'python3 week03/session_3_1/run_query.py "$WORK/review_03.sql"'
echo "## The reviewer checks the new column against a count they trust"
cat > "$WORK/check.sql" <<'SQL'
SELECT drug_name,
       COUNT(*) AS reports,
       COUNT(serious) AS reports_with_a_code,
       COUNT(*) FILTER (WHERE serious = '1') AS serious_reports
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'serious': 'VARCHAR'})
WHERE drug_name IN ('DUPIXENT', 'CABOMETYX', 'SKYRIZI')
GROUP BY drug_name
ORDER BY reports DESC, drug_name;
SQL
run 'cat "$WORK/check.sql"'
run 'python3 week03/session_3_1/run_query.py "$WORK/check.sql"'
run 'git status --short'
echo "=== CHECK"
echo "-- commits on the branch"; git log --format=%s main..origin/feature/top10-serious-share
echo "-- changed"; git diff --stat main...origin/feature/top10-serious-share | tail -1
echo "-- the branch's serious_reports"
python3 week03/session_3_1/run_query.py "$WORK/review_03.sql" | grep -E "DUPIXENT|CABOMETYX|SKYRIZI"
echo "-- the counts it should show"
python3 week03/session_3_1/run_query.py "$WORK/check.sql" | grep -E "DUPIXENT|CABOMETYX|SKYRIZI"
echo "-- your main"; [ "$(git rev-parse main)" = "$(git rev-parse origin/main)" ] && echo "unchanged, same as GitHub"
