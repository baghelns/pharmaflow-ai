#!/usr/bin/env bash
# a2_rebuild_from_a_pip_freeze.sh -- Session 4.2 Assignments Solutions (trainer copy): Assignment 2: requirements.txt from a colleague's pip freeze
# Replays the assignment in a throwaway folder; your repository is not changed.
# Run from anywhere inside pharmaflow-ai:
#   bash week04/session_4_2/assign_solutions/a2_rebuild_from_a_pip_freeze.sh
# The lines after "=== CHECK" must match expected_output/a2_rebuild_from_a_pip_freeze.txt.
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
run 'bash "$HELPER" a2'
[ -d "$PRACTICE_DIR/messy/.git" ] || { echo "Cannot replay: a2 failed (see above)."; exit 2; }
cd "$PRACTICE_DIR/messy"

run 'git log --oneline -1'
run 'wc -l < ravi_freeze.txt'
run 'python3 "$CHECKREQ" .'
echo "## Take only what the code needs, at the versions Ravi's code ran with"
run 'grep -iE "^(duckdb|matplotlib|numpy|openpyxl|pandas|seaborn)==" ravi_freeze.txt'
run "printf '# pandas read_excel needs openpyxl (never imported)\nopenpyxl==3.1.5\nduckdb==2.0.0\nmatplotlib==3.11.2\nnumpy==2.4.6\npandas==3.0.5\nseaborn==0.13.2\n' > requirements.txt"
run 'cat -A requirements.txt'
run 'python3 "$CHECKREQ" . | tail -3'
run 'git commit -am "requirements: what the code needs, pinned to the versions it ran with"'
run 'git status --short'
run 'python3 load_reference.py'
run 'bash "$HELPER" check-a2'
echo "=== CHECK"
cat requirements.txt
python3 load_reference.py
bash "$HELPER" check-a2
