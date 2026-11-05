#!/usr/bin/env bash
# 03_ex2_requirements.sh -- Session 4.2 Git Solutions (trainer copy): Exercise 2: can someone else install this?
# Replays the exercise in a throwaway folder; your repository is not changed.
# Run from anywhere inside pharmaflow-ai:
#   bash week04/session_4_2/git_solutions/03_ex2_requirements.sh
# The lines after "=== CHECK" must match expected_output/03_ex2_requirements.txt.
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
export PRACTICE_DIR="$WORK/practice"
run 'bash "$HELPER" setup'
[ -d "$PRACTICE_DIR/messy/.git" ] || { echo "Cannot replay: setup failed (see above)."; exit 2; }
cd "$PRACTICE_DIR/messy"

run 'cat -A requirements.txt'
run 'python3 "$CHECKREQ" .'
printf 'duckdb==2.0.0\nmatplotlib==3.11.2\npandas==3.0.5\nseaborn==0.13.2\n' > requirements.txt
echo "(rewrote requirements.txt in the editor)"; echo
run 'cat -A requirements.txt'
run 'python3 "$CHECKREQ" .'
run 'git commit -am "requirements: every import pinned, once; drop unused requests"'
echo "## A brand-new, empty Python environment cannot run the code yet"
run 'python3 -m venv "$WORK/fresh"'
run '"$WORK/fresh/bin/python" report.py'
echo "=== CHECK"
echo "-- requirements.txt"; cat requirements.txt
echo "-- checker"; python3 "$CHECKREQ" . | tail -1
echo "-- empty environment"
out=$("$WORK/fresh/bin/python" report.py 2>&1) || true
echo "$out" | tail -1
