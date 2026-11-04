#!/usr/bin/env bash
# 01_warmup_canteen_menu.sh -- Session 4.1 Git Solutions (trainer copy): Warm-Up: the canteen menu
# Replays the exercise in a throwaway folder; your repository is not changed.
# Run from anywhere inside pharmaflow-ai:
#   bash week04/session_4_1/git_solutions/01_warmup_canteen_menu.sh
# The lines after "=== CHECK" must match expected_output/01_warmup_canteen_menu.txt.
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
cd "$WORK" && mkdir playground && cd playground
run 'git init -b main'
run "printf 'Masala chai, 15\nSamosa, 20\nPoha, 25\n' > menu.txt"
run 'git status --short'
run 'git add menu.txt'
run 'git status --short'
run 'git commit -m "Opening menu: chai, samosa, poha"'
echo "## Part B: a branch that main has not moved past (fast-forward)"
run 'git switch -c add-vada'
run 'echo "Vada pav, 18" >> menu.txt'
run 'git commit -am "Add vada pav"'
run 'git switch main'
run 'git merge add-vada'
echo "## Part C: both sides moved (3-way merge)"
run 'git switch -c add-lassi'
run 'echo "Sweet lassi, 30" >> menu.txt'
run 'git commit -am "Add sweet lassi"'
run 'git switch main'
edit menu.txt 'Poha, 25' 'Poha, 22'
run 'git commit -am "Poha down to 22"'
run 'git merge --no-edit add-lassi'
echo "## Part D: both sides changed the same line (conflict)"
run 'git switch -c chai-price'
edit menu.txt 'Masala chai, 15' 'Masala chai, 18'
run 'git commit -am "Chai up to 18"'
run 'git switch main'
edit menu.txt 'Masala chai, 15' 'Masala chai, 20'
run 'git commit -am "Chai up to 20"'
run 'git merge chai-price'
run 'cat menu.txt'
edit menu.txt 're:<<<<<<< HEAD\n.*?>>>>>>> chai-price\n' 'Masala chai, 20
'
run 'git diff --check && echo "no conflict markers left"'
run 'git add menu.txt'
run 'git commit --no-edit'
echo "=== CHECK"
echo "-- menu.txt"; cat menu.txt
echo "-- history"; git log --graph --format=%s
echo "-- status"; [ -z "$(git status --short)" ] && echo "(clean)" || git status --short
