# Session 4.1 Assignments Solutions (trainer copy)

Three replay scripts, one per assignment. Each builds its own practice team
in a throwaway folder, plays the student's part, prints every command with its
real output, and deletes the folder at the end. Your repository is not changed.

They need the Assignments version of `week04/session_4_1/practice_team.sh`
(the one with the `a1`, `a2` and `a3` commands) and, committed on `main`:
`week04/session_4_1/top10_drugs.sql`, `week03/session_3_1/run_query.py`,
`data/raw/adverse_events_10k.csv` and `README.md`.

Run from the repo root (any folder inside the repo works):

    bash week04/session_4_1/assign_solutions/a1_has_the_answer_changed.sh

To check all three against the expected output:

    for s in a1_has_the_answer_changed a2_hotfix_while_mid_feature \
             a3_find_and_undo_a_silent_change; do
        out=$(bash week04/session_4_1/assign_solutions/$s.sh 2>&1 | sed -n '/=== CHECK/,$p')
        if [ "$out" = "$(cat week04/session_4_1/assign_solutions/expected_output/$s.txt)" ]
        then echo "OK    $s"; else echo "DIFF  $s"; fi
    done

`<id>` in the output stands for a commit ID, `<work>` for the throwaway folder.
