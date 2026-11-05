#!/usr/bin/env bash
# a1_ignore_the_data_drop.sh -- Session 4.2 Assignments Solutions (trainer copy): Assignment 1: ignore rules for a data drop
# Replays the assignment in a throwaway folder; your repository is not changed.
# Run from anywhere inside pharmaflow-ai:
#   bash week04/session_4_2/assign_solutions/a1_ignore_the_data_drop.sh
# The lines after "=== CHECK" must match expected_output/a1_ignore_the_data_drop.txt.
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
HELPER="$REPO/week04/session_4_2/practice_repo_4_2.sh"
CHECKREQ="$REPO/week04/session_4_2/check_requirements.py"
LINKS="$(cd "$(dirname "$0")" && pwd)/check_readme_links.py"

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
for f in "$HELPER" "$CHECKREQ"; do
    [ -f "$f" ] || { echo "Cannot replay: put $(basename "$f") in week04/session_4_2/"; exit 2; }
done
grep -q '^a1)' "$HELPER" || {
    echo "Cannot replay: replace week04/session_4_2/practice_repo_4_2.sh with the"
    echo "Assignments version (it has the a1, a2 and a3 commands)."; exit 2; }
export PRACTICE_DIR="$WORK/practice"
run 'bash "$HELPER" a1'
[ -d "$PRACTICE_DIR/messy/.git" ] || { echo "Cannot replay: a1 failed (see above)."; exit 2; }
cd "$PRACTICE_DIR/messy"

run 'git status --short --untracked-files=all'
echo "## Write the rules, then test them before committing anything"
run "printf '\n# Clinical Operations data drop (Assignment 1)\nlogs/\nexports/*\n!exports/README.md\n*-Copy*.ipynb\n.DS_Store\n~\$*\n*.local.json\n' >> .gitignore"
run 'tail -9 .gitignore'
run 'git check-ignore -v --non-matching logs/pipeline_2026-10-30.log exports/events_2026-10.csv exports/README.md analysis-Copy1.ipynb .DS_Store data/raw/.DS_Store "data/raw/~\$drug_classes.xlsx" config/settings.local.json config/settings.json data/raw/drug_classes.csv'
run 'git status --short --untracked-files=all'
run 'git add .gitignore exports/README.md data/raw/drug_classes.csv config/settings.json'
run 'git commit -m "Ignore generated and local files from the data drop; keep its inputs and notes"'
run 'git status --short --untracked-files=all'
run 'bash "$HELPER" check-a1'
echo "=== CHECK"
git ls-files | sort
bash "$HELPER" check-a1
