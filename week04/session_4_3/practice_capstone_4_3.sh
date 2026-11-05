#!/usr/bin/env bash
# practice_capstone_4_3.sh -- Session 4.3: practice material for the Capstone
# exercises, on your own disk, so nothing touches your real repository.
#
# Put this file in week04/session_4_3/ and run it from any folder inside
# your pharmaflow-ai repo:
#
#   bash week04/session_4_3/practice_capstone_4_3.sh setup
#
# "setup" creates week04/session_4_3/practice/ with:
#   draft_talk.md     a first draft of a 5-minute Capstone talk (Exercise 4)
#   weak_findings.md  a Findings section written in a hurry (Exercise 3)
#   toy_repo/         a tiny Git repository with a broken SQL library (Exercise 5)
# Running "setup" again deletes the folder and starts over.
set -euo pipefail

REPO=$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null) || {
    echo "Keep this file inside your pharmaflow-ai repo (week04/session_4_3/)." >&2; exit 1; }
case "$REPO" in
    */week04/session_4_3/practice/*) REPO=${REPO%/week04/session_4_3/practice/*} ;;
esac
PRACTICE=${PRACTICE_DIR:-$REPO/week04/session_4_3/practice}
START_DIR=$PWD

case "${1:-}" in
setup)
    if [ -z "${PRACTICE_DIR:-}" ] && ! git -C "$REPO" check-ignore -q "week04/session_4_3/practice/x"; then
        echo "week04/session_4_3/practice/ is not in .gitignore yet." >&2
        echo "Add the line  week04/session_4_3/practice/  to .gitignore and commit it first." >&2
        exit 1
    fi
    for f in 03_top10_drugs 08_bulk_submissions; do
        [ -f "$REPO/data/processed/library/$f.parquet" ] || {
            echo "Missing data/processed/library/$f.parquet: run python week03/session_3_3/run_library.py first." >&2
            exit 1; }
    done
    cd "$REPO"
    rm -rf "$PRACTICE"
    mkdir -p "$PRACTICE"
    cat > "$PRACTICE/draft_talk.md" <<'TALK'
# PharmaFlow Foundation: my Capstone talk (first draft)

Good morning everyone. Thank you for having me. So, my name is Asha and
today I am going to be talking to you about my project, which is called
PharmaFlow Foundation. Before I start I just want to say that this project
took a lot of work over four weeks and I learned a lot of things, like
Python, pandas, matplotlib, seaborn, SQL, DuckDB, Git and GitHub, and also
how to work in a Codespace, which was new for me. I want to thank my
trainer and my teammates for all their help.

So first, some background. The FDA in America collects reports from
doctors, patients and companies when something goes wrong after someone
takes a medicine. These are called adverse event reports. The FDA puts them
online in a system called openFDA, and anyone can download them with an
API. An API is a way for one program to ask another program for data. In
Week 1 I learned how to call the API with the requests library, and how to
handle pages and errors like 429, which means too many requests. That was
quite difficult at first, but then I understood it.

In Week 2 I used pandas. Pandas is a Python library for tables. I loaded
6,218 reports into a DataFrame and I profiled them. Profiling means looking
at every column to see what is in it. I found that a lot of ages were
missing. Then I made five charts with matplotlib and seaborn. I am going to
show you all five charts now, one by one, and explain how I made each one,
including the colours and the titles, because I spent a lot of time on
them.

In Week 3 I learned SQL with DuckDB. DuckDB is a database that can read
CSV and Parquet files directly. I wrote ten queries and saved them as .sql
files in a library, and each one saves its answer as a Parquet file.
Parquet is a column file format that is smaller and faster than CSV.

In Week 4 I learned Git. I made branches, pull requests and tags, and I
tidied my repository with a README and a requirements file.

Now the results. The drug with the most reports is DUPIXENT with 621
reports. That is a lot more than the second one, CABOMETYX, which has 170.
The serious share goes up and down every quarter, and it is lowest in 2026
Q1 at 30 percent. Death or hospital care reactions are serious 92 percent
of the time, which makes sense. The biggest drug class is the Interleukin-4
Receptor alpha Antagonist class with 630 reports. And age is missing in
almost half of the reports, 48.5 percent.

So in conclusion, DUPIXENT is the most dangerous drug in the data, because
it has the most adverse event reports. Also 2026 Q1 was a safer quarter.
I think this project shows that I can do data engineering from start to
finish. In the future I would like to add more data and maybe build a
dashboard, and maybe use machine learning to predict which reports are
serious. That is the end of my talk. Thank you very much for listening.
Are there any questions?
TALK
    cat > "$PRACTICE/weak_findings.md" <<'WEAK'
## Findings

### Q1
DUPIXENT is the top drug, it has the most reports by far. See the chart.

### Q2
The serious share changes a lot, the lowest quarter was 2026 Q1 which
means it was a safer quarter.

### Q3
Death and heart reactions are the most serious ones
([chart](data/processed/charts/lab3_heatmap.png)).

### Q4
The biggest class is the Interleukin-4 class with 630 reports
([query](queries/05_drug_classes.sql)).
WEAK
    mkdir -p "$PRACTICE/toy_repo"
    cd "$PRACTICE/toy_repo"
    git init -q -b main
    git config user.name "Toy"; git config user.email "toy@pharmaflow.example"
    mkdir -p data/processed/library
    cp "$REPO/data/processed/library/03_top10_drugs.parquet" data/processed/library/
    printf 'this is not a Parquet file\n' > data/processed/library/08_bulk_submissions.parquet
    git add -A
    git commit -q -m "a library with one good file, one broken file and three missing"
    echo "Practice material ready in week04/session_4_3/practice/:"
    echo "  draft_talk.md ($(wc -w < "$PRACTICE/draft_talk.md") words), weak_findings.md, toy_repo/"
    case "$START_DIR/" in "$PRACTICE"/*) echo "Your terminal was inside the old practice folder, which was replaced. Run:"; echo "  cd $PRACTICE" ;; esac
    ;;
*)
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
