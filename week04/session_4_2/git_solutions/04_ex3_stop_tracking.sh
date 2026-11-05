#!/usr/bin/env bash
# 04_ex3_stop_tracking.sh -- Session 4.2 Git Solutions (trainer copy): Exercise 3: stop tracking what should never have been committed
# Replays the exercise in a throwaway folder; your repository is not changed.
# Run from anywhere inside pharmaflow-ai:
#   bash week04/session_4_2/git_solutions/04_ex3_stop_tracking.sh
# The lines after "=== CHECK" must match expected_output/04_ex3_stop_tracking.txt.
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

run 'bash "$HELPER" check3'
run 'git ls-files -z | xargs -0 du -k | sort -n | tail -3'
run 'git ls-files | grep -E "(^|/)(__pycache__|\.ipynb_checkpoints)/|(^|/)\.env$"'
run 'cat .gitignore'
run 'git check-ignore -v --non-matching openfda_raw_pull.json'
printf '*raw_pull*.json\n.env\n__pycache__/\n.ipynb_checkpoints/\n' > .gitignore
echo "(rewrote .gitignore in the editor)"; echo
run 'cat .gitignore'
run 'git status --short'
run 'git rm --cached openfda_raw_pull.json .env'
run 'git rm -r --cached __pycache__ .ipynb_checkpoints'
run 'git add .gitignore'
run 'git status --short'
run 'git commit -m "Stop tracking the raw pull, .env and generated folders; ignore them"'
run 'git status --short'
run 'ls -la openfda_raw_pull.json .env'
run 'bash "$HELPER" check3'
echo "## Still in the history: the key must be changed, not just untracked"
run 'git show HEAD~1:.env'
echo "=== CHECK"
bash "$HELPER" check3
echo "-- .env in the commit before the clean-up"; git show HEAD~1:.env
