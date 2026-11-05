# Session 4.2 Assignments Solutions (trainer copy)

Three replay scripts, one per assignment. Each builds its assignment's
practice repository in a throwaway folder, plays the student's part, prints
every command with its real output, and deletes the folder at the end.
Your repository and your practice/ folder are not changed.

They need, in `week04/session_4_2/`: the Assignments version of
`practice_repo_4_2.sh` (it has the a1, a2 and a3 commands) and
`check_requirements.py`.

Check all three against the expected output, from the repo root:

    for s in week04/session_4_2/assign_solutions/a*.sh; do
        n=$(basename "$s" .sh)
        out=$(bash "$s" 2>&1 | sed -n '/=== CHECK/,$p')
        if [ "$out" = "$(cat week04/session_4_2/assign_solutions/expected_output/$n.txt)" ]
        then echo "OK    $n"; else echo "DIFF  $n"; fi
    done

`<id>` in the output stands for a commit ID, `<work>` for the throwaway folder.
