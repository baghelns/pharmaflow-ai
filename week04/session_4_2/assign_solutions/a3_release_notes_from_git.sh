#!/usr/bin/env bash
# a3_release_notes_from_git.sh -- Session 4.2 Assignments Solutions (trainer copy): Assignment 3: release notes for v0.2, from Git
# Replays the assignment in a throwaway folder; your repository is not changed.
# Run from anywhere inside pharmaflow-ai:
#   bash week04/session_4_2/assign_solutions/a3_release_notes_from_git.sh
# The lines after "=== CHECK" must match expected_output/a3_release_notes_from_git.txt.
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
run 'bash "$HELPER" a3'
[ -d "$PRACTICE_DIR/messy/.git" ] || { echo "Cannot replay: a3 failed (see above)."; exit 2; }
cd "$PRACTICE_DIR/messy"

run 'git log --oneline v0.1..HEAD'
run 'git log --name-status --format="== %s" v0.1..HEAD'
echo "## The release is the difference between the two snapshots, not the list of commits"
run 'git diff --name-status -M v0.1 HEAD'
run "cat > CHANGELOG.md <<'MD'
# Changelog

## v0.2

Tidied for review: code moved into folders, a rewritten report script,
and the raw download and the API key file no longer tracked. Both are
still in v0.1's history, so the key in .env must be replaced.

### Added
- data/raw/README.md
- scripts/report.py

### Changed
- .gitignore
- README.md
- requirements.txt

### Moved
- analysis.ipynb -> notebooks/analysis.ipynb
- top10.sql -> queries/top10.sql

### Removed
- .env
- openfda_raw_pull.json
- report.py
MD"
run 'git add CHANGELOG.md'
run 'git commit -m "CHANGELOG: what changed since v0.1"'
run 'git tag -a v0.2 -m "Practice repo v0.2: tidied, see CHANGELOG.md"'
run 'git cat-file -t v0.2'
run 'git status --short'
run 'bash "$HELPER" check-a3'
echo "=== CHECK"
git diff --name-status -M v0.1 v0.2
bash "$HELPER" check-a3
