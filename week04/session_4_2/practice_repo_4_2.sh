#!/usr/bin/env bash
# practice_repo_4_2.sh -- Session 4.2: a messy practice repository, on your
# own disk, so you can practise tidying a repo without touching your real one.
#
# Put this file in week04/session_4_2/ and run it from any folder inside
# your pharmaflow-ai repo:
#
#   bash week04/session_4_2/practice_repo_4_2.sh setup    # build (or rebuild) the messy repo
#   bash week04/session_4_2/practice_repo_4_2.sh check3   # check your Exercise 3 answer
#   bash week04/session_4_2/practice_repo_4_2.sh check4   # check your Exercise 4 answer
#
# "setup" creates week04/session_4_2/practice/messy/: a small Git repository
# that a previous intern left behind, with the problems real repos have.
# Running "setup" again deletes it and starts over.
set -euo pipefail

REPO=$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null) || {
    echo "Keep this file inside your pharmaflow-ai repo (week04/session_4_2/)." >&2; exit 1; }
case "$REPO" in
    */week04/session_4_2/practice/*) REPO=${REPO%/week04/session_4_2/practice/*} ;;
esac
PRACTICE=${PRACTICE_DIR:-$REPO/week04/session_4_2/practice}
MESSY=$PRACTICE/messy

need_messy() {
    [ -d "$MESSY/.git" ] || {
        echo "No practice repo yet. Run: bash week04/session_4_2/practice_repo_4_2.sh setup" >&2
        exit 1; }
}

case "${1:-}" in
setup)
    if [ -z "${PRACTICE_DIR:-}" ] && ! git -C "$REPO" check-ignore -q "week04/session_4_2/practice/x"; then
        echo "week04/session_4_2/practice/ is not in .gitignore yet." >&2
        echo "Add the line  week04/session_4_2/practice/  to .gitignore and commit it first." >&2
        exit 1
    fi
    # Step out first: your terminal may be inside the folder being replaced.
    case "$PWD/" in "$MESSY"/*) was_inside=yes ;; *) was_inside=no ;; esac
    cd "$REPO"
    rm -rf "$MESSY"
    mkdir -p "$MESSY"
    cd "$MESSY"
    git init -q -b main
    git config user.name "Asha (previous intern)"
    git config user.email "asha@pharmaflow.example"
    export GIT_AUTHOR_DATE="2026-09-14T10:00:00+05:30" GIT_COMMITTER_DATE="2026-09-14T10:00:00+05:30"
    python3 - <<'PY'
import json, os, random
random.seed(42)
os.makedirs("data/raw", exist_ok=True)
drugs = ["DUPIXENT", "CABOMETYX", "SKYRIZI", "RINVOQ", "HUMIRA", "VICTOZA"]
rows = ["safety_report_id,drug_name,serious"]
n = 0
for drug, count in zip(drugs, [7, 4, 3, 3, 2, 1]):
    for _ in range(count):
        n += 1
        rows.append(f"{90000 + n},{drug},{random.choice('12')}")
open("data/raw/sample.csv", "w").write("\n".join(rows) + "\n")
# the raw API pull an earlier script saved in the wrong folder (about 9 MB)
records = [{"safetyreportid": str(10000000 + i), "receivedate": "20260601",
            "patient": {"drug": [{"medicinalproduct": random.choice(drugs)}],
                        "reaction": [{"reactionmeddrapt": "Headache"}]},
            "padding": "x" * 120} for i in range(30000)]
json.dump({"results": records}, open("openfda_raw_pull.json", "w"))
open("top10.sql", "w").write(
    "-- Top drugs in the sample\n"
    "SELECT drug_name, COUNT(*) AS reports\n"
    "FROM read_csv('data/raw/sample.csv', types = {'serious': 'VARCHAR'})\n"
    "GROUP BY drug_name\n"
    "ORDER BY reports DESC, drug_name;\n")
open("report.py", "w").write(
    '"""Print the top drugs in the sample (run from the repo root)."""\n'
    "import duckdb\n\n"
    'with open("top10.sql") as f:\n'
    "    query = f.read()\n"
    "duckdb.sql(query).show()\n")
nb = {"cells": [
        {"cell_type": "code", "execution_count": None, "id": "c1", "metadata": {},
         "outputs": [], "source": ["import pandas as pd\n", "import matplotlib.pyplot as plt\n",
                                   "import seaborn as sns\n"]},
        {"cell_type": "code", "execution_count": None, "id": "c2", "metadata": {},
         "outputs": [], "source": ["df = pd.read_csv('data/raw/sample.csv')\n",
                                   "df['drug_name'].value_counts().plot.barh()"]}],
      "metadata": {"language_info": {"name": "python"}}, "nbformat": 4, "nbformat_minor": 5}
json.dump(nb, open("analysis.ipynb", "w"), indent=1)
os.makedirs(".ipynb_checkpoints", exist_ok=True)
json.dump(nb, open(".ipynb_checkpoints/analysis-checkpoint.ipynb", "w"), indent=1)
os.makedirs("__pycache__", exist_ok=True)
open("__pycache__/report.cpython-311.pyc", "wb").write(bytes(range(256)) * 4)
open(".env", "w").write("OPENFDA_API_KEY=demo-key-123\n")
open("requirements.txt", "w").write("pandas==3.0.5\nrequests\npandas==3.0.5\nduckdb==2.0.0")
open("README.md", "w").write(
    "# pharmaflow\n\nmy project\n\n![Top drugs](charts/top_drugs.png)\n\n"
    "Setup: see [the setup notes](docs/setup.md).\n")
open(".gitignore", "w").write("data/raw/*raw_pull*.json\n")
PY
    git add -A
    git commit -q -m "first upload"
    export GIT_AUTHOR_DATE="2026-09-15T16:30:00+05:30" GIT_COMMITTER_DATE="2026-09-15T16:30:00+05:30"
    printf -- '-- Top drugs in the sample (checked: DUPIXENT 7)\n' > .hdr
    { cat .hdr; tail -n +2 top10.sql; } > .t && mv .t top10.sql && rm .hdr
    git commit -q -am "top10: note the check value"
    unset GIT_AUTHOR_DATE GIT_COMMITTER_DATE
    echo "Practice repo ready: week04/session_4_2/practice/messy/"
    echo "  $(git ls-files | wc -l) committed files, $(git rev-list --count HEAD) commits by a previous intern"
    echo "  cd week04/session_4_2/practice/messy"
    if [ "$was_inside" = yes ]; then
        echo "Your terminal was inside the old practice repo, which is gone. Run:"
        echo "  cd $MESSY"
    fi
    ;;
check3)
    need_messy
    cd "$MESSY"
    pass=0; total=0
    check() {
        total=$((total + 1)); local what=$1; shift
        if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); echo "PASS  $what"
        else echo "FAIL  $what"; fi
    }
    not_tracked() { [ -z "$(git ls-files -- "$1")" ]; }
    ignored() { git check-ignore -q --no-index "$1"; }
    on_disk() { [ -e "$1" ]; }
    clean() { [ -z "$(git status --short)" ]; }
    check "openfda_raw_pull.json is no longer tracked" not_tracked openfda_raw_pull.json
    check "openfda_raw_pull.json is still on disk" on_disk openfda_raw_pull.json
    check ".env is no longer tracked, and is ignored" eval 'not_tracked .env && ignored .env'
    check "__pycache__/ is no longer tracked, and is ignored" eval 'not_tracked __pycache__ && ignored __pycache__/x.pyc'
    check ".ipynb_checkpoints/ is no longer tracked, and is ignored" eval 'not_tracked .ipynb_checkpoints && ignored .ipynb_checkpoints/x.ipynb'
    check "a raw pull saved at the root would now be ignored" ignored openfda_raw_pull_2.json
    check "everything is committed (git status is clean)" clean
    echo "$pass of $total checks passed"
    ;;
check4)
    need_messy
    cd "$MESSY"
    pass=0; total=0
    check() {
        total=$((total + 1)); local what=$1; shift
        if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); echo "PASS  $what"
        else echo "FAIL  $what"; fi
    }
    tracked() { [ -n "$(git ls-files -- "$1")" ]; }
    history_follows() {
        local f
        for f in scripts/report.py queries/top10.sql notebooks/analysis.ipynb; do
            [ "$(git log --follow --format=%s -- "$f" | tail -1)" = "first upload" ] || return 1
        done; }
    report_runs() {
        local out
        out=$(cd scripts && python3 report.py 2>&1) || return 1
        [[ "$out" == *"DUPIXENT"* ]]
    }
    report_runs_root() {
        local out
        out=$(python3 scripts/report.py 2>&1) || return 1
        [[ "$out" == *"DUPIXENT"* ]]
    }
    clean() { [ -z "$(git status --short)" ]; }
    check "scripts/report.py, queries/top10.sql, notebooks/analysis.ipynb exist" \
        eval 'tracked scripts/report.py && tracked queries/top10.sql && tracked notebooks/analysis.ipynb'
    check "no script, query or notebook left at the repo root" \
        eval '[ -z "$(git ls-files | grep -v / | grep -E "\.(py|sql|ipynb)$")" ]'
    check "the notebook no longer reads data/raw/sample.csv relative to its own folder" \
        eval '[ -f notebooks/analysis.ipynb ] && ! grep -q "read_csv(.data/raw/sample.csv.)" notebooks/analysis.ipynb'
    check "all three moved files keep their history (git log --follow)" history_follows
    check "scripts/report.py runs from the repo root" report_runs_root
    check "scripts/report.py runs from inside scripts/" report_runs
    check "everything is committed (git status is clean)" clean
    echo "$pass of $total checks passed"
    ;;
*)
    sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
