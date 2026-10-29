"""Week 3 Mini Project · Data Request Ticket · run-time estimate

The ticket asks for an estimate of how long the query takes. One run on
6,218 rows says little about a bigger file, so this script times the
ticket's counting step (every report's week and drug class, counted) on
the real CSV and on copies 10 and 100 times its size, and on the 100x
copy saved as Parquet, the way Session 3.3's Exercise 5 did.

The copies are for timing only: every count in them is exactly 10 or 100
times the real one, and they are deleted when the script ends.

Run from the repo root:          python week03/mini_project/time_ticket_query.py
or from week03/mini_project:     python time_ticket_query.py
Lines that start with "time" change from run to run and machine to
machine; every other line is the same everywhere.
"""
import os
import sys
import tempfile
import time


def find_repo_root(marker_folder="data", start=None):
    """Search upward from the current folder for the folder that contains
    `data` -- that folder is the repo root."""
    current = os.path.abspath(start or os.getcwd())
    while True:
        if os.path.isdir(os.path.join(current, marker_folder)):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            raise FileNotFoundError(f"No '{marker_folder}' folder above {os.getcwd()}")
        current = parent


REPO_ROOT = find_repo_root()
sys.path.insert(0, os.path.join(REPO_ROOT, "week03", "session_3_1"))
from run_query import connect_to_repo  # noqa: E402

# The ticket's counting step: one row per week and drug class.
WEEKLY_SQL = """
SELECT CAST(date_trunc('week', strptime(e.event_date, '%Y%m%d')) AS DATE)
           AS week_start,
       COALESCE(d.drug_class, 'No class') AS drug_class,
       COUNT(*) AS reports
FROM {source} AS e
LEFT JOIN read_csv('data/raw/drug_reference.csv') AS d
       ON e.drug_name = d.drug_name
GROUP BY week_start, drug_class
"""


def best_of_3(task):
    """Run task() three times; return its result and the fastest time."""
    times = []
    for _ in range(3):
        start = time.perf_counter()
        result = task()
        times.append(time.perf_counter() - start)
    return result, min(times)


def weekly_counts(con, source):
    """Run the counting step; return (groups, total reports)."""
    sql = WEEKLY_SQL.format(source=source)
    return con.sql(f"SELECT COUNT(*), SUM(reports) FROM ({sql})").fetchall()[0]


con = connect_to_repo()
results = []
with tempfile.TemporaryDirectory() as tmp:
    sources = [("real file (1x)", "read_csv('data/raw/adverse_events_10k.csv', "
                "all_varchar = true)", "data/raw/adverse_events_10k.csv")]
    for copies in (10, 100):
        path = os.path.join(tmp, f"events_x{copies}.csv").replace("\\", "/")
        # Every row joined with the numbers 0..copies-1: each report
        # appears `copies` times; all_varchar keeps every column as text.
        con.execute(f"""
            COPY (SELECT e.*
                  FROM read_csv('data/raw/adverse_events_10k.csv',
                                all_varchar = true) AS e
                  CROSS JOIN range({copies}))
            TO '{path}' (HEADER)""")
        sources.append((f"{copies}x copy, CSV",
                        f"read_csv('{path}', all_varchar = true)", path))
    pq = os.path.join(tmp, "events_x100.parquet").replace("\\", "/")
    con.execute(f"""COPY (SELECT * FROM read_csv('{tmp}/events_x100.csv',
                                                 all_varchar = true))
                    TO '{pq}' (FORMAT parquet)""")
    sources.append(("100x copy, Parquet", f"'{pq}'", pq))

    for label, source, path in sources:
        (groups, total), seconds = best_of_3(lambda: weekly_counts(con, source))
        size = os.path.getsize(path if os.path.isabs(path)
                               else os.path.join(REPO_ROOT, path))
        results.append((label, total, groups, size, seconds))

print("Same groups in every file, every count scaled:")
for label, total, groups, size, _ in results:
    print(f"  {label:<20} {total:>9,} reports  {groups:>4} week-class groups"
          f"  {size / 1e6:6.1f} MB")
print()
for label, total, _, _, seconds in results:
    print(f"time {label:<20} {seconds * 1000:8.1f} ms"
          f"   ({seconds / total * 1e6 * 1000:6.1f} ms per million rows)")
