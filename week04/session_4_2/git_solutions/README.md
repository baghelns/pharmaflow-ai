# Session 4.2 Git Solutions (trainer copy)

Six replay scripts, one per exercise, plus `check_readme_links.py` (the
Exercise 5 solution). Each script builds the practice repository in a
throwaway folder, plays the student's part, prints every command with its
real output, and deletes the folder at the end. Your repository is not
changed.

They need, in `week04/session_4_2/`: `practice_repo_4_2.sh` and
`check_requirements.py`.

Check all six against the expected output, from the repo root:

    for s in week04/session_4_2/git_solutions/0*.sh; do
        n=$(basename "$s" .sh)
        out=$(bash "$s" 2>&1 | sed -n '/=== CHECK/,$p')
        if [ "$out" = "$(cat week04/session_4_2/git_solutions/expected_output/$n.txt)" ]
        then echo "OK    $n"; else echo "DIFF  $n"; fi
    done

`<id>` in the output stands for a commit ID, `<work>` for the throwaway folder.
Exercise 2's install into an empty environment needs the internet, so the
replay stops before it; run that step by hand (Exercise Workbook, Task C).
