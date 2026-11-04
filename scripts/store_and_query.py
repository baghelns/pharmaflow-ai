"""PharmaFlow Foundation pipeline, step 3 of 3: store as Parquet, ask SQL.

Run from any folder inside the pharmaflow-ai repo, after clean.py:

    python scripts/store_and_query.py

Reads  data/processed/foundation/events_clean.csv (from clean.py).
Writes data/processed/foundation/events.parquet      (every clean report)
       data/processed/foundation/top10_drugs.parquet (the answer)
Uses DuckDB through Session 3.1's run_query.py, and Session 3.3's
repo_file() so COPY writes to the same place from any folder.
"""
import os
import sys


def find_repo_root(marker_folder="data", start=None):
    """Search upward from the current folder for the folder that contains
    `data` -- that folder is the repo root."""
    current = os.path.abspath(start or os.getcwd())
    while True:
        if os.path.isdir(os.path.join(current, marker_folder)):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            raise FileNotFoundError(
                f"No '{marker_folder}' folder above {os.getcwd()}")
        current = parent


REPO_ROOT = find_repo_root()
sys.path.insert(0, os.path.join(REPO_ROOT, "week03", "session_3_1"))
from run_query import connect_to_repo, run_sql  # noqa: E402

STORE = """
CREATE OR REPLACE MACRO repo_file(p) AS
    current_setting('file_search_path') || '/' || p;

-- IDs, codes and dates as text (Session 3.1); age_years as a number.
CREATE OR REPLACE TABLE events AS
SELECT * REPLACE (CAST(strptime(event_date, '%Y%m%d') AS DATE) AS event_date)
FROM read_csv('data/processed/foundation/events_clean.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'age_years': 'DOUBLE',
                       'country': 'VARCHAR',
                       'event_date': 'VARCHAR',
                       'possible_duplicate': 'BOOLEAN'});

COPY events
TO (repo_file('data/processed/foundation/events.parquet'))
    (FORMAT parquet);

-- The Stage 0 question, asked of the stored Parquet file.
CREATE OR REPLACE TABLE top10 AS
SELECT drug_name,
       COUNT(*) AS reports,
       ROUND(100.0 * COUNT(*) FILTER (WHERE serious = '1')
             / COUNT(serious), 1) AS pct_serious
FROM 'data/processed/foundation/events.parquet'
GROUP BY drug_name
ORDER BY reports DESC, drug_name
LIMIT 10;

COPY top10
TO (repo_file('data/processed/foundation/top10_drugs.parquet'))
    (FORMAT parquet);
"""

CHECK = """
SELECT (SELECT COUNT(*) FROM read_csv(
            'data/processed/foundation/events_clean.csv',
            all_varchar = true)) AS csv_rows,
       (SELECT COUNT(*)
        FROM 'data/processed/foundation/events.parquet') AS parquet_rows,
       (SELECT COUNT(DISTINCT safety_report_id)
        FROM 'data/processed/foundation/events.parquet') AS distinct_ids
"""


def main():
    con = connect_to_repo()
    run_sql(STORE, con)                  # CREATE and COPY: nothing to print
    print("store: wrote data/processed/foundation/events.parquet")
    print("store: wrote data/processed/foundation/top10_drugs.parquet")
    print("query: top 10 drugs by number of reports")
    run_sql("SELECT * FROM top10 ORDER BY reports DESC, drug_name", con)
    csv_rows, parquet_rows, distinct_ids = con.sql(CHECK).fetchall()[0]
    ok = csv_rows == parquet_rows == distinct_ids
    print(f"check: {csv_rows} rows in the CSV, {parquet_rows} in the "
          f"Parquet file, {distinct_ids} distinct report IDs")
    print("Pipeline OK" if ok else "Pipeline CHECK FAILED: counts differ")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
