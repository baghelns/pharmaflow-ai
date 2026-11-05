#!/usr/bin/env bash
# 06_ex5_readme_link_checker.sh -- Session 4.2 Git Solutions (trainer copy): Exercise 5 (Interview Challenge): check every README link
# Replays the exercise in a throwaway folder; your repository is not changed.
# Run from anywhere inside pharmaflow-ai:
#   bash week04/session_4_2/git_solutions/06_ex5_readme_link_checker.sh
# The lines after "=== CHECK" must match expected_output/06_ex5_readme_link_checker.txt.
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

run 'cat README.md'
run 'python3 "$LINKS" .'
echo "## A toy repository with every kind of link"
cd "$WORK" && git init -q edge && cd edge
mkdir -p docs img && echo x > docs/setup.md && echo p > img/a.png
cat > README.md <<'MD'
# Edge cases
![chart](img/a.png "A title")
[setup](docs/setup.md#install) and [folder](docs/) and [site](https://example.com) and [top](#edge-cases)
[mail](mailto:a@b.c) [root](/img/a.png) [up](../outside.md) [missing](img/b.png)
```
![in code](not/real.png)
```
[two](docs/setup.md) on a line with [three](nope.md)
MD
git add -A && git commit -q -m "edge cases"
cd "$WORK" && git init -q nocommits && mkdir plain
run 'cat edge/README.md'
run 'python3 "$LINKS" edge nocommits plain /no/such/folder'
echo "## Your own repository"
run 'python3 "$LINKS" "$REPO"'
echo "=== CHECK"
python3 "$LINKS" "$PRACTICE_DIR/messy" | sed "s|$WORK|<work>|"
(cd "$WORK" && python3 "$LINKS" edge nocommits plain /no/such/folder)
