# Session 4.3 Exercise Solutions (trainer copy)

Three .sql files (Warm-Up, Exercises 1 and 2), two .py files (Exercises 3
and 5) and the model talk for Exercise 4. Every query reads the committed
Parquet answers in data/processed/library/; nothing in the repository changes.

They need, in week04/session_4_3/: practice_capstone_4_3.sh (run its setup
first) and check_capstone_4_3.py (Exercise 3 imports its Findings rules).

Check them against the expected output, from the repo root:

    S=week04/session_4_3/sql_solutions
    for f in $S/0*.sql; do n=$(basename "$f" .sql)
        python week03/session_3_1/run_query.py "$f" | diff -q - "$S/expected_output/$n.txt" >/dev/null && echo "OK    $n" || echo "DIFF  $n"
    done
    python $S/04_ex3_panel_score.py week04/session_4_3/practice/weak_findings.md | diff -q - $S/expected_output/04_ex3_panel_score.txt >/dev/null && echo "OK    04_ex3_panel_score" || echo "DIFF  04_ex3_panel_score"
    python $S/06_ex5_answer_table.py . week04/session_4_3/practice/toy_repo /no/such/folder | diff -q - $S/expected_output/06_ex5_answer_table.txt >/dev/null && echo "OK    06_ex5_answer_table" || echo "DIFF  06_ex5_answer_table"
