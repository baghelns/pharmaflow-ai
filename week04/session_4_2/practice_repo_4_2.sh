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
#   bash week04/session_4_2/practice_repo_4_2.sh a1       # Assignment 1 (then check-a1)
#   bash week04/session_4_2/practice_repo_4_2.sh a2       # Assignment 2 (then check-a2)
#   bash week04/session_4_2/practice_repo_4_2.sh a3       # Assignment 3 (then check-a3)
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
START_DIR=$PWD

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
a1)
    # Assignment 1: a data drop from Clinical Operations lands in the repo.
    bash "$0" setup >/dev/null
    cd "$MESSY"
    mkdir -p logs exports config data/raw
    printf '2026-10-30 09:12 ingest: 300 raw reports\n' > logs/pipeline_2026-10-30.log
    printf 'safety_report_id,drug_name\n91001,DUPIXENT\n' > exports/events_2026-10.csv
    printf 'safety_report_id,drug_name\n91002,RINVOQ\n' > exports/events_2026-11.csv
    printf '# exports/\n\nMonthly CSV exports for Clinical Operations. The pipeline\nrewrites them every month; only this note is kept in Git.\n' > exports/README.md
    cp analysis.ipynb analysis-Copy1.ipynb
    printf 'Bud1' > .DS_Store
    printf 'Bud1' > data/raw/.DS_Store
    printf 'drug_name,drug_class\nDUPIXENT,Interleukin-4 Receptor alpha Antagonist\n' > data/raw/drug_classes.csv
    printf 'lock' > 'data/raw/~$drug_classes.xlsx'
    printf '{"database": "data/processed/pharmaflow.duckdb"}\n' > config/settings.json
    printf '{"database": "/home/asha/test.duckdb", "api_key": "demo-key-456"}\n' > config/settings.local.json
    echo "Assignment 1 ready in week04/session_4_2/practice/messy/:"
    echo "  the Clinical Operations data drop is in the folder, not committed yet."
    echo "  git status --short --untracked-files=all"
    case "$START_DIR/" in "$MESSY"/*) echo "Your terminal was inside the old practice repo, which was replaced. Run:"; echo "  cd $MESSY" ;; esac
    ;;
check-a1)
    need_messy
    cd "$MESSY"
    pass=0; total=0
    check() {
        total=$((total + 1)); local what=$1; shift
        if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); echo "PASS  $what"
        else echo "FAIL  $what"; fi
    }
    ignored() { git check-ignore -q --no-index "$1"; }
    all_ignored() { local f; for f in "$@"; do ignored "$f" || return 1; done; }
    none_ignored() { local f; for f in "$@"; do ! ignored "$f" || return 1; done; }
    tracked() { local f; for f in "$@"; do [ -n "$(git ls-files -- "$f")" ] || return 1; done; }
    nothing_ignored_tracked() { [ -z "$(git ls-files -ci --exclude-standard)" ]; }
    clean() { [ -z "$(git status --short --untracked-files=all)" ]; }
    check "logs and the monthly exports are ignored" all_ignored logs/pipeline_2026-10-30.log logs/later.log exports/events_2026-10.csv exports/events_2026-12.csv
    check "exports/README.md is kept and committed" eval 'none_ignored exports/README.md && tracked exports/README.md'
    check "Jupyter's -Copy notebooks are ignored, analysis.ipynb is not" eval 'all_ignored analysis-Copy1.ipynb notebooks/x-Copy2.ipynb && none_ignored analysis.ipynb'
    check ".DS_Store and Office lock files are ignored in every folder" all_ignored .DS_Store data/raw/.DS_Store 'data/raw/~$drug_classes.xlsx' 'docs/~$plan.docx'
    check "the new input data/raw/drug_classes.csv is committed" eval 'none_ignored data/raw/drug_classes.csv && tracked data/raw/drug_classes.csv'
    check "settings.local.json is ignored; config/settings.json is committed" eval 'all_ignored config/settings.local.json && none_ignored config/settings.json && tracked config/settings.json'
    check "no ignored file is tracked" nothing_ignored_tracked
    check "everything is committed (git status is clean)" clean
    echo "$pass of $total checks passed"
    ;;
a2)
    # Assignment 2: a teammate's script, and the pip freeze from their Codespace.
    bash "$0" setup >/dev/null
    cd "$MESSY"
    git config user.name "Ravi (Data Engineer)"
    git config user.email "ravi@pharmaflow.example"
    python3 -c '
import pandas as pd
pd.DataFrame({"drug_name": ["DUPIXENT", "CABOMETYX", "SKYRIZI", "RINVOQ", "HUMIRA", "VICTOZA"],
              "drug_class": ["Interleukin-4 Receptor alpha Antagonist", "Kinase Inhibitor",
                             "Interleukin-23 Antagonist", "Janus Kinase Inhibitor",
                             "Tumor Necrosis Factor Blocker", "GLP-1 Receptor Agonist"]}
             ).to_excel("data/raw/drug_classes.xlsx", index=False)
' || { echo "Could not write the Excel file: pip install --user openpyxl==3.1.5, then run a2 again." >&2; exit 1; }
    printf '%s\n' '"""Share of serious reports per drug class (run from the repo root)."""' \
        'import numpy as np' 'import pandas as pd' '' \
        'classes = pd.read_excel("data/raw/drug_classes.xlsx")' \
        'events = pd.read_csv("data/raw/sample.csv", dtype={"serious": str})' \
        'df = events.merge(classes, on="drug_name", how="left", validate="many_to_one")' \
        'df["is_serious"] = np.where(df["serious"] == "1", 1.0, 0.0)' \
        'print(df.groupby("drug_class")["is_serious"].mean().round(2))' > load_reference.py
    git add load_reference.py data/raw/drug_classes.xlsx
    git commit -q -m "Serious share per drug class, from the Excel reference"
    printf '%s\n' anyio==4.11.0 argon2-cffi==25.1.0 asttokens==3.0.0 black==25.9.0 \
        certifi==2025.10.5 charset-normalizer==3.4.4 contourpy==1.3.3 cycler==0.12.1 \
        debugpy==1.8.17 decorator==5.2.1 duckdb==2.0.0 et_xmlfile==2.0.0 executing==2.2.1 \
        fonttools==4.68.0 idna==3.11 ipykernel==7.3.0 ipython==9.6.0 jedi==0.19.2 \
        Jinja2==3.1.6 jupyter==1.1.1 jupyterlab==4.4.10 kiwisolver==1.5.1 \
        matplotlib==3.11.2 numpy==2.4.6 openpyxl==3.1.5 packaging==26.3 pandas==3.0.5 \
        pillow==13.0.0 pyparsing==3.3.3 python-dateutil==4.0.0 requests==2.34.2 \
        seaborn==0.13.2 six==1.17.0 tornado==6.5.2 tzdata==2026.6 urllib3==2.5.0 > ravi_freeze.txt
    echo "Assignment 2 ready in week04/session_4_2/practice/messy/:"
    echo "  Ravi committed load_reference.py and data/raw/drug_classes.xlsx;"
    echo "  ravi_freeze.txt (not committed) is the pip freeze from his Codespace."
    case "$START_DIR/" in "$MESSY"/*) echo "Your terminal was inside the old practice repo, which was replaced. Run:"; echo "  cd $MESSY" ;; esac
    ;;
check-a2)
    need_messy
    cd "$MESSY"
    CHECKREQ=$(cd "$(dirname "$0")" && pwd)/check_requirements.py
    pass=0; total=0
    check() {
        total=$((total + 1)); local what=$1; shift
        if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); echo "PASS  $what"
        else echo "FAIL  $what"; fi
    }
    req_ok() { local out; out=$(python3 "$CHECKREQ" . 2>&1); [ "${out##*$'\n'}" = "requirements.txt OK" ]; }
    pkgs() { grep -v '^[[:space:]]*#' requirements.txt | grep -v '^[[:space:]]*$' | sed 's/[=<>~!].*//' | tr 'A-Z_' 'a-z-' | sort | tr '\n' ' '; }
    exact_set() { [ "$(pkgs)" = "duckdb matplotlib numpy openpyxl pandas seaborn " ]; }
    pins_match() {
        local line
        [ -f ravi_freeze.txt ] || return 1
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in ''|\#*) continue ;; esac
            grep -qixF -- "$line" ravi_freeze.txt || return 1
        done < requirements.txt; }
    has_comment() { grep -qi '^#.*openpyxl' requirements.txt; }
    freeze_not_committed() { [ -z "$(git ls-files -- ravi_freeze.txt)" ]; }
    committed() { git diff --quiet HEAD -- requirements.txt; }
    check "check_requirements.py prints requirements.txt OK" req_ok
    check "exactly the packages the code needs: duckdb matplotlib numpy openpyxl pandas seaborn" exact_set
    check "every version is the one in Ravi's freeze" pins_match
    check "a comment says why openpyxl is listed" has_comment
    check "ravi_freeze.txt is not committed" freeze_not_committed
    check "requirements.txt is committed" committed
    echo "$pass of $total checks passed"
    ;;
a3)
    # Assignment 3: v0.1 was released; the team changed a lot; v0.2 needs release notes.
    bash "$0" setup >/dev/null
    cd "$MESSY"
    git tag -a v0.1 -m "Practice repo v0.1: as the previous intern left it"
    as() { git config user.name "$1"; git config user.email "$2@pharmaflow.example"; }
    when() { export GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1"; }
    when "2026-10-20T10:00:00+05:30"; as "Ravi (Data Engineer)" ravi
    mkdir -p queries notebooks scripts
    git mv top10.sql queries/top10.sql
    git mv analysis.ipynb notebooks/analysis.ipynb
    git commit -q -m "Move the query and the notebook into queries/ and notebooks/"
    when "2026-10-21T11:00:00+05:30"; as "Meera (Analytics Engineer)" meera
    git rm -q report.py
    printf '%s\n' '"""Print the top drugs in the sample, from any folder."""' \
        'from pathlib import Path' '' 'import duckdb' '' \
        'ROOT = Path(__file__).resolve().parent.parent' \
        'con = duckdb.connect()' \
        "con.execute(f\"SET file_search_path = '{ROOT}'\")" \
        'con.sql((ROOT / "queries" / "top10.sql").read_text()).show()' > scripts/report.py
    printf 'TODO: check the report runs from scripts/\n' > scratch_notes.md
    git add scripts/report.py scratch_notes.md
    git commit -q -m "Rewrite the report as scripts/report.py; runs from any folder"
    when "2026-10-22T15:00:00+05:30"; as "Ravi (Data Engineer)" ravi
    printf '*raw_pull*.json\n.env\n' > .gitignore
    git rm -q --cached openfda_raw_pull.json .env
    git add .gitignore
    git commit -q -m "Stop tracking the raw pull and .env"
    when "2026-10-23T12:00:00+05:30"; as "Meera (Analytics Engineer)" meera
    printf 'duckdb==2.0.0\nmatplotlib==3.11.2\npandas==3.0.5\nseaborn==0.13.2\n' > requirements.txt
    printf '# PharmaFlow top drugs (practice repo)\n\nRun: python scripts/report.py\n' > README.md
    printf '# data/raw/\n\nsample.csv: 20 toy reports (safety_report_id, drug_name, serious).\n' > data/raw/README.md
    git rm -q scratch_notes.md
    git add requirements.txt README.md data/raw/README.md
    git commit -q -m "README, data notes and a pinned requirements.txt; drop scratch notes"
    unset GIT_AUTHOR_DATE GIT_COMMITTER_DATE
    git config user.name "You"; git config user.email "you@pharmaflow.example"
    echo "Assignment 3 ready in week04/session_4_2/practice/messy/:"
    echo "  v0.1 is tagged; $(git rev-list --count v0.1..HEAD) commits by the team since then."
    echo "  git log --oneline v0.1..HEAD"
    case "$START_DIR/" in "$MESSY"/*) echo "Your terminal was inside the old practice repo, which was replaced. Run:"; echo "  cd $MESSY" ;; esac
    ;;
check-a3)
    need_messy
    cd "$MESSY"
    pass=0; total=0
    check() {
        total=$((total + 1)); local what=$1; shift
        if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); echo "PASS  $what"
        else echo "FAIL  $what"; fi
    }
    # what Git says changed between the releases (the notes themselves left out)
    truth() {
        git diff --name-status -M v0.1 v0.2 -- . ':!CHANGELOG.md' 2>/dev/null | awk -F'\t' '
            $1 == "A" { print "Added: " $2 } $1 == "M" { print "Changed: " $2 }
            $1 == "D" { print "Removed: " $2 } $1 ~ /^R/ { print "Moved: " $2 " -> " $3 }' | sort; }
    notes() {
        git show v0.2:CHANGELOG.md 2>/dev/null | tr -d '\r' | awk '
            /^## / { inrel = ($2 == "v0.2"); sect = ""; next }
            inrel && /^### / { sect = $2; next }
            inrel && sect != "" && /^- / { sub(/^- /, ""); sub(/[ \t]+$/, ""); gsub(/`/, ""); print sect ": " $0 }' | sort; }
    has_tag() { git rev-parse -q --verify v0.2 >/dev/null; }
    tag_annotated() { [ "$(git cat-file -t v0.2 2>/dev/null)" = tag ]; }
    tag_on_main() { [ "$(git rev-parse -q --verify 'v0.2^{commit}')" = "$(git rev-parse main)" ]; }
    v01_unchanged() { [ "$(git log -1 --format=%s 'v0.1^{commit}')" = "top10: note the check value" ]; }
    has_section() { git show v0.2:CHANGELOG.md 2>/dev/null | grep -q '^## v0.2'; }
    missing() { comm -23 <(truth) <(notes); }
    extra() { comm -13 <(truth) <(notes); }
    clean() { [ -z "$(git status --short)" ]; }
    check "v0.2 is an annotated tag on the latest commit of main" eval 'tag_annotated && tag_on_main'
    check "v0.1 still points at the old release" v01_unchanged
    check "CHANGELOG.md in v0.2 has a ## v0.2 section" has_section
    check "every change Git reports since v0.1 is in the notes" eval 'has_tag && [ -z "$(missing)" ]'
    check "the notes list nothing Git does not report" eval 'has_tag && [ -z "$(extra)" ]'
    check "everything is committed (git status is clean)" clean
    echo "$pass of $total checks passed"
    if has_tag && [ -n "$(missing)" ]; then
        echo "Missing from the notes:"; missing | sed 's/^/  /'; fi
    if has_tag && [ -n "$(extra)" ]; then
        echo "In the notes, but not what Git reports:"; extra | sed 's/^/  /'; fi
    ;;
*)
    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
