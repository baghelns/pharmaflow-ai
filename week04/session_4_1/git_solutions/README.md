# Session 4.1 — Git Solutions (trainer copy)

One replay script per exercise in the Session 4.1 Exercise Workbook. Each
script works in a **throwaway folder** that it deletes at the end: it never
changes your repository, your branches or GitHub. It prints every command with
its output (commit IDs and the throwaway folder's path shown as `<id>` and
`<work>`), and ends with a block that starts `=== CHECK`. That block is the
same on every machine and is kept in `expected_output/`.

| Script | Exercise |
|---|---|
| `01_warmup_canteen_menu.sh` | Warm-Up: fast-forward, 3-way merge, conflict |
| `02_ex1_history_and_restore.sh` | Exercise 1: history, restore the deleted top-10 file, undo an edit |
| `03_ex2_experiment_branch.sh` | Exercise 2: top 10 without bulk submissions, on a branch |
| `04_ex3_rejected_push_conflict.sh` | Exercise 3: rejected push, fetch, conflict, resolve |
| `05_ex4_review_teammate_branch.sh` | Exercise 4: review Ravi's branch without merging |
| `06_ex5_undo_pushed_commit.sh` | Exercise 5: revert a pushed commit; the reset + push that fails |

## Where the files go

```
week04/session_4_1/practice_team.sh              (the student helper)
week04/session_4_1/git_solutions/0*.sh           (these scripts)
week04/session_4_1/git_solutions/expected_output/0*.txt
week04/session_4_1/git_solutions/README.md
```

The scripts need, committed on `main`: `week04/session_4_1/top10_drugs.sql`,
`week03/session_3_1/run_query.py` and `data/raw/adverse_events_10k.csv`.
Scripts 04–06 also need `week04/session_4_1/practice_team.sh` in place.
If something is missing, a script stops at once with
`Cannot replay: <file> is not committed on main.` and the check prints DIFF.
The Git Solutions are trainer material: keep them out of the students' repos.

## Run one

From the repo root:

```
bash week04/session_4_1/git_solutions/04_ex3_rejected_push_conflict.sh
```

Some commands in the output end with `(exit code 1)` or `(exit code 128)`.
That is intended: a conflict, a rejected push, a deleted file or a refused
branch deletion is what the exercise shows.

## Check all six before class

From the repo root, this prints `OK` or `DIFF` for each script (about a
minute in total):

```
cd /workspaces/pharmaflow-ai
for f in week04/session_4_1/git_solutions/0*.sh; do
  n=$(basename "$f" .sh)
  if bash "$f" 2>&1 | sed -n '/^=== CHECK/,$p' |
     diff -q - "week04/session_4_1/git_solutions/expected_output/$n.txt" >/dev/null
  then echo "OK   $n"; else echo "DIFF $n"; fi
done
```

The scripts create nothing in your repository. Each makes one folder under
`/tmp` and deletes it when it finishes.
