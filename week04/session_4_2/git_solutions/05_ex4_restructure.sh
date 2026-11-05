#!/usr/bin/env bash
# 05_ex4_restructure.sh -- Session 4.2 Git Solutions (trainer copy): Exercise 4: move files without losing their history
# Replays the exercise in a throwaway folder; your repository is not changed.
# Run from anywhere inside pharmaflow-ai:
#   bash week04/session_4_2/git_solutions/05_ex4_restructure.sh
# The lines after "=== CHECK" must match expected_output/05_ex4_restructure.txt.
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

run 'mkdir -p scripts queries notebooks'
run 'git mv report.py scripts/'
run 'git mv top10.sql queries/'
run 'git mv analysis.ipynb notebooks/'
run 'git status --short'
run 'git commit -m "Move code into scripts/, queries/ and notebooks/"'
run 'python3 scripts/report.py'
run 'git grep -n -e "top10.sql" -e "data/raw/" -- "*.py" "*.ipynb" "*.sql"'
cat > scripts/report.py <<'PY'
"""Print the top drugs in the sample (run from any folder)."""
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent      # the repository folder
query = (ROOT / "queries" / "top10.sql").read_text()
con = duckdb.connect()
con.execute(f"SET file_search_path = '{ROOT}'")    # data/raw/... from ROOT
con.sql(query).show()
PY
echo "(rewrote scripts/report.py in the editor)"; echo
run 'cat scripts/report.py'
run 'python3 scripts/report.py'
run 'cd scripts && python3 report.py'
python3 - <<'PY'

import json
nb = json.load(open("notebooks/analysis.ipynb"))
cell = nb["cells"][1]
cell["source"] = [
    "import os\n",
    "\n",
    "def find_repo_root(marker_folder='data', start=None):\n",
    "    current = os.path.abspath(start or os.getcwd())\n",
    "    while not os.path.isdir(os.path.join(current, marker_folder)):\n",
    "        parent = os.path.dirname(current)\n",
    "        if parent == current:\n",
    "            raise FileNotFoundError('no data folder above here')\n",
    "        current = parent\n",
    "    return current\n",
    "\n",
    "df = pd.read_csv(os.path.join(find_repo_root(), 'data', 'raw', 'sample.csv'))\n",
    "df['drug_name'].value_counts().plot.barh()"]
json.dump(nb, open("notebooks/analysis.ipynb", "w"), indent=1)
PY
echo "(edited the second cell of notebooks/analysis.ipynb in Jupyter)"; echo
cat > "$WORK/run_nb.py" <<'PY'

import json, sys
nb = json.load(open(sys.argv[1]))
code = "\n".join("".join(c["source"]) for c in nb["cells"] if c["cell_type"] == "code")
exec(compile(code, sys.argv[1], "exec"), {})
print("notebook cells ran without an error")
PY
run 'cd notebooks && MPLBACKEND=Agg python3 "$WORK/run_nb.py" analysis.ipynb'
run 'git add -A'
run 'git status --short'
run 'git commit -m "Fix the paths that broke when the files moved"'
run 'git log --oneline -- scripts/report.py'
run 'git log --oneline --follow -- scripts/report.py'
run 'bash "$HELPER" check4'
echo "=== CHECK"
echo "-- history of scripts/report.py, following the move"
git log --follow --format=%s -- scripts/report.py
bash "$HELPER" check4
