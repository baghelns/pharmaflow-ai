#!/usr/bin/env bash
# 01_warmup_gitignore_rules.sh -- Session 4.2 Git Solutions (trainer copy): Warm-Up: how .gitignore rules match
# Replays the exercise in a throwaway folder; your repository is not changed.
# Run from anywhere inside pharmaflow-ai:
#   bash week04/session_4_2/git_solutions/01_warmup_gitignore_rules.sh
# The lines after "=== CHECK" must match expected_output/01_warmup_gitignore_rules.txt.
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
cd "$WORK" && mkdir playground && cd playground
run 'git init -b main'
run 'mkdir -p build logs src/build'
run 'touch notes.txt build/app.bin logs/today.log src/build/keep.txt secret.env keep.env'
run "printf '*.log\n/build/\n*.env\n!keep.env\n' > .gitignore"
run 'cat .gitignore'
run 'git status --short --untracked-files=all'
run 'git check-ignore -v --non-matching logs/today.log build/app.bin src/build/keep.txt secret.env keep.env notes.txt'
echo "## The trap: a file committed before it is ignored"
run 'git add .gitignore notes.txt keep.env src'
run 'git commit -m "Start the playground"'
run 'echo "notes.txt" >> .gitignore'
run 'echo "a second line" >> notes.txt'
run 'git status --short'
run 'git check-ignore -v notes.txt'
run 'git check-ignore -v --no-index notes.txt'
run 'git rm --cached notes.txt'
run 'git commit -am "Stop tracking notes.txt; ignore it"'
run 'git status --short'
run 'ls notes.txt'
echo "=== CHECK"
echo "-- tracked"; git ls-files
echo "-- ignored on disk"; git status --short --ignored | sort
