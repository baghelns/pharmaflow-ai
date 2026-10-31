#!/usr/bin/env bash
# practice_team.sh -- Session 4.1: a pretend GitHub and a pretend teammate,
# on your own disk, so you can practise team Git without touching your
# real repository on github.com.
#
# Put this file in week04/session_4_1/ and run it from any folder inside
# your pharmaflow-ai repo:
#
#   bash week04/session_4_1/practice_team.sh setup   # build the practice team
#   bash week04/session_4_1/practice_team.sh ex3     # teammate pushes (Exercise 3)
#   bash week04/session_4_1/practice_team.sh ex4     # teammate shares a branch (Exercise 4)
#   bash week04/session_4_1/practice_team.sh ex5     # teammate pushes a bad change (Exercise 5)
#   bash week04/session_4_1/practice_team.sh check5  # check your Exercise 5 answer
#
# "setup" creates week04/session_4_1/practice/ with three folders:
#   github.git  the pretend GitHub (a "bare" repository: history only, no files to edit)
#   you         your copy: you work here (cd week04/session_4_1/practice/you)
#   teammate    Ravi's copy: only this script works here
# Running "setup" again deletes those three folders and starts over.
# It never deletes practice/playground (the Warm-Up).
set -euo pipefail

REPO=$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null) || {
    echo "Keep this file inside your pharmaflow-ai repo (week04/session_4_1/)." >&2; exit 1; }
# Run from inside practice/you or practice/teammate, Git reports that copy
# as the repository; the real repo is the folder above week04/.
case "$REPO" in
    */week04/session_4_1/practice/*) REPO=${REPO%/week04/session_4_1/practice/*} ;;
esac
PRACTICE=${PRACTICE_DIR:-$REPO/week04/session_4_1/practice}
GITHUB=$PRACTICE/github.git
YOU=$PRACTICE/you
MATE=$PRACTICE/teammate
LIB=week04/session_4_1/top10_drugs.sql

need_team() {
    [ -d "$YOU/.git" ] && [ -d "$MATE/.git" ] || {
        echo "No practice team yet. Run: bash week04/session_4_1/practice_team.sh setup" >&2
        exit 1; }
}

# The teammate always starts from the latest pretend-GitHub main.
mate_sync() {
    git -C "$MATE" switch -q main
    git -C "$MATE" pull -q --ff-only origin main
}

# Replace one block of text in a file of the teammate's copy (exactly once).
mate_replace() {
    python3 - "$MATE/$1" "$2" "$3" <<'PY'
import sys
path, old, new = sys.argv[1:4]
text = open(path, encoding="utf-8").read()
if text.count(old) != 1:
    sys.exit(f"practice_team.sh: expected text not found once in {path}")
open(path, "w", encoding="utf-8").write(text.replace(old, new))
PY
}

case "${1:-}" in
setup)
    if [ -z "${PRACTICE_DIR:-}" ] && ! git -C "$REPO" check-ignore -q "week04/session_4_1/practice/x"; then
        echo "week04/session_4_1/practice/ is not in .gitignore yet." >&2
        echo "Add the line  week04/session_4_1/practice/  to .gitignore and commit it first." >&2
        exit 1
    fi
    # The practice copies are made from your committed main branch, so the
    # files the exercises use must be committed there.
    missing=0
    for f in "$LIB" week03/session_3_1/run_query.py data/raw/adverse_events_10k.csv; do
        if ! git -C "$REPO" cat-file -e "main:$f" 2>/dev/null; then
            echo "Not committed on main: $f" >&2; missing=1
        fi
    done
    if [ "$missing" = 1 ]; then
        echo "Commit (and push) these files first; see Set up your session." >&2
        exit 1
    fi
    # Step out first: your terminal may be inside the folders being replaced.
    case "$PWD/" in "$PRACTICE"/*) was_inside=yes ;; *) was_inside=no ;; esac
    cd "$REPO"
    rm -rf "$GITHUB" "$YOU" "$MATE" "$PRACTICE/.ex5_bad_commit"
    mkdir -p "$PRACTICE"
    # The pretend GitHub starts as a copy of your committed main branch.
    git clone -q --bare --single-branch --branch main "$REPO" "$GITHUB"
    git clone -q "$GITHUB" "$YOU"
    git clone -q "$GITHUB" "$MATE"
    # Your copy commits under your own name; Ravi commits under his.
    git -C "$YOU" config user.name "$(git -C "$REPO" config user.name || echo Student)"
    git -C "$YOU" config user.email "$(git -C "$REPO" config user.email || echo student@example.com)"
    git -C "$MATE" config user.name "Ravi (teammate)"
    git -C "$MATE" config user.email "ravi@pharmaflow.example"
    echo "Practice team ready in week04/session_4_1/practice/"
    echo "  github.git  pretend GitHub ($(git -C "$GITHUB" rev-list --count main) commits on main)"
    echo "  you         your copy: cd week04/session_4_1/practice/you"
    echo "  teammate    Ravi's copy (leave it to this script)"
    if [ "$was_inside" = yes ]; then
        echo "Your terminal was inside the old practice folder, which is gone. Run:"
        echo "  cd $YOU"
    fi
    ;;
ex3)
    need_team; mate_sync
    mate_replace "$LIB" \
"-- Notes    : Several of the ten are there because of one bulk submission
--            (Week 2)." \
"-- Notes    : Several of the ten are there because of one bulk submission
--            (Week 2). Reviewed with the Pharmacovigilance Lead."
    git -C "$MATE" commit -q -am "Record the Pharmacovigilance review of the top-10 file"
    git -C "$MATE" push -q origin main
    echo "Ravi pushed to main: \"Record the Pharmacovigilance review of the top-10 file\""
    ;;
ex4)
    need_team; mate_sync
    git -C "$MATE" switch -q -C feature/top10-serious-share
    mate_replace "$LIB" \
"       ROUND(100.0 * COUNT(*) FILTER (WHERE serious = '1')
             / COUNT(serious), 1) AS pct_serious
FROM events
GROUP BY drug_name" \
"       COUNT(serious) AS serious_reports,
       ROUND(100.0 * COUNT(*) FILTER (WHERE serious = '1')
             / COUNT(serious), 1) AS pct_serious
FROM events
GROUP BY drug_name"
    mate_replace "$LIB" \
"SELECT * FROM answer ORDER BY reports DESC, drug_name;" \
"SELECT drug_name, reports, serious_reports, pct_serious
FROM answer
ORDER BY reports DESC, drug_name;"
    git -C "$MATE" commit -q -am "Top 10: add the number of serious reports"
    git -C "$MATE" push -q --force origin feature/top10-serious-share
    git -C "$MATE" switch -q main
    echo "Ravi pushed a branch: feature/top10-serious-share (asks you to review it)"
    ;;
ex5)
    need_team; mate_sync
    mate_replace "$LIB" "LIMIT 10;" "LIMIT 1;"
    git -C "$MATE" commit -q -am "Top 10: show only the leading drug"
    printf '\nQuestions about the data: ask the Data Manager.\n' >> "$MATE/README.md"
    git -C "$MATE" commit -q -am "README: say who answers data questions"
    git -C "$MATE" push -q origin main
    # Remember the bad commit, so check5 can tell if it was erased.
    git -C "$MATE" rev-parse HEAD~1 > "$PRACTICE/.ex5_bad_commit"
    echo "Ravi pushed 2 commits to main:"
    git -C "$MATE" log --format='  %h %s' -2
    ;;
check5)
    need_team
    git -C "$YOU" fetch -q origin
    [ -f "$PRACTICE/.ex5_bad_commit" ] || {
        echo "Run ex5 first: bash week04/session_4_1/practice_team.sh ex5"; exit 1; }
    BAD=$(cat "$PRACTICE/.ex5_bad_commit")
    pass=0; total=0
    check() {  # check "<what>" <command...>
        total=$((total + 1)); local what=$1; shift
        if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); echo "PASS  $what"
        else echo "FAIL  $what"; fi
    }
    on_github() { git -C "$GITHUB" merge-base --is-ancestor "$1" main; }
    same_as_before_bad() {
        diff -q <(git -C "$MATE" show "$BAD^:$LIB") <(git -C "$GITHUB" show "main:$LIB"); }
    pushed() { [ "$(git -C "$YOU" rev-parse main)" = "$(git -C "$GITHUB" rev-parse main)" ]; }
    readme_kept() { git -C "$GITHUB" grep -q "ask the Data Manager" main -- README.md; }
    ten_rows() {
        # Capture first, then search: piping into grep -q can stop the
        # query mid-print and fail the check at random.
        local out
        out=$(cd "$YOU" && git show "origin/main:$LIB" > "$PRACTICE/.check5.sql" &&
              python3 week03/session_3_1/run_query.py "$PRACTICE/.check5.sql") || return 1
        [[ "$out" == *"10 rows"* ]]
    }
    check "the bad commit is still in the history (nothing rewritten)" on_github "$BAD"
    check "top10_drugs.sql on GitHub matches the version before the bad commit" same_as_before_bad
    check "Ravi's README commit after it is still there" readme_kept
    check "your main is pushed (your copy and GitHub agree)" pushed
    check "the file on GitHub returns 10 rows again" ten_rows
    rm -f "$PRACTICE/.check5.sql"
    echo "$pass of $total checks passed"
    ;;
*)
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
