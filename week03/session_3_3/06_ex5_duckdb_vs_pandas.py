"""Session 3.3 · Exercise 5 · Interview Challenge
"The Same Answer, Faster"

Question: on a file 100 times the size of ours, which five drugs have
the most reports, and what share of each drug's reports is serious?
Answer it with pandas and with DuckDB, prove the answers are the same,
and time both.

Constraints: DuckDB reads the file itself (no pandas on the DuckDB
side); the script checks the two answers in code; every timing is the
best of 3 runs; nothing large is left behind in the repo.

Data: data/raw/adverse_events_10k.csv (6,218 reports), copied 100
times into a temporary folder. The copy is for timing only: every
count in it is exactly 100 times the real one.

Run from the repo root:      python week03/session_3_3/06_ex5_duckdb_vs_pandas.py
or from week03/session_3_3:  python 06_ex5_duckdb_vs_pandas.py
Lines that start with "time" change from run to run and machine to
machine; every other line is the same everywhere.
"""
import os
import sys
import tempfile
import time

import pandas as pd


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

TOP_5_SQL = """
SELECT drug_name,
       COUNT(*) AS reports,
       100.0 * COUNT(*) FILTER (WHERE serious = '1')
             / COUNT(serious) AS pct_serious
FROM {source}
GROUP BY drug_name
ORDER BY reports DESC, drug_name
LIMIT 5
"""


def best_of_3(task):
    """Run task() three times; return its result and the fastest time."""
    times = []
    for _ in range(3):
        start = time.perf_counter()
        result = task()
        times.append(time.perf_counter() - start)
    return result, min(times)


def top5_pandas(csv_path):
    df = pd.read_csv(csv_path, dtype=str)  # IDs and codes stay text
    grouped = df.groupby("drug_name")
    answer = pd.DataFrame({
        "reports": grouped.size(),
        "pct_serious": 100.0 * grouped["serious"].agg(lambda s: (s == "1").sum())
                       / grouped["serious"].count(),
    }).reset_index()
    answer = answer.sort_values(["reports", "drug_name"],
                                ascending=[False, True]).head(5)
    return answer.reset_index(drop=True)


def top5_duckdb(con, source):
    return con.sql(TOP_5_SQL.format(source=source)).df()


con = connect_to_repo()
with tempfile.TemporaryDirectory() as tmp:
    big_csv = os.path.join(tmp, "events_x100.csv").replace("\\", "/")
    big_parquet = os.path.join(tmp, "events_x100.parquet").replace("\\", "/")

    # Build the 100x copy: every row of the CSV joined with the numbers
    # 0-99, so each report appears 100 times. all_varchar keeps every
    # column as text, exactly as the original file has it.
    con.execute(f"""
        COPY (SELECT e.*
              FROM read_csv('data/raw/adverse_events_10k.csv',
                            all_varchar = true) AS e
              CROSS JOIN range(100))
        TO '{big_csv}' (HEADER)""")
    con.execute(f"""COPY (SELECT * FROM read_csv('{big_csv}', all_varchar = true))
                    TO '{big_parquet}' (FORMAT parquet)""")

    rows = con.sql(f"SELECT COUNT(*) FROM '{big_parquet}'").fetchall()[0][0]
    print(f"Rows in the 100x copy: {rows:,} (6,218 x 100 = {6218 * 100:,})")
    print(f"CSV size: {os.path.getsize(big_csv) / 1e6:.1f} MB")

    csv_source = f"read_csv('{big_csv}', all_varchar = true)"
    pandas_answer, t_pandas = best_of_3(lambda: top5_pandas(big_csv))
    duck_csv, t_duck_csv = best_of_3(lambda: top5_duckdb(con, csv_source))
    duck_parquet, t_duck_pq = best_of_3(
        lambda: top5_duckdb(con, f"'{big_parquet}'"))

# The check: same drugs, same counts, and shares equal to 9 decimals.
same = (
    list(pandas_answer["drug_name"]) == list(duck_csv["drug_name"])
    == list(duck_parquet["drug_name"])
    and list(pandas_answer["reports"]) == list(duck_csv["reports"])
    == list(duck_parquet["reports"])
    and (pandas_answer["pct_serious"] - duck_csv["pct_serious"]).abs().max() < 1e-9
    and (duck_csv["pct_serious"] - duck_parquet["pct_serious"]).abs().max() < 1e-9
)
print("pandas and DuckDB answers:", "MATCH" if same else "DIFFERENT")
print()
shown = duck_parquet.copy()
shown["pct_serious"] = shown["pct_serious"].round(1)
shown["reports_in_real_file"] = shown["reports"] // 100
print(shown.to_string(index=False))
print()
print(f"time pandas  read_csv + groupby : {t_pandas:6.3f} s")
print(f"time DuckDB  on the CSV         : {t_duck_csv:6.3f} s")
print(f"time DuckDB  on the Parquet     : {t_duck_pq:6.3f} s")
print(f"time pandas / DuckDB-on-CSV     : {t_pandas / t_duck_csv:6.1f} x")
