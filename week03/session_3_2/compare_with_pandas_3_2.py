"""Session 3.2 Lab -- compare your SQL quarter-on-quarter change with pandas.

Put this file in week03/session_3_2/. Paste your Lab query 2 between the
triple quotes of LAG_QUERY below, then run, from the repo root:

    python week03/session_3_2/compare_with_pandas_3_2.py

Your query may use the `events` view (this script creates it, with the
report_date column, exactly as in the workbook). It must return one row per
quarter with at least these two columns:
    qtr         the quarter's first day, as a DATE (e.g. 2025-04-01)
    pct_change  the change on the previous quarter, in percent, rounded
                to one decimal
A quarter counts as a MATCH when both sides agree within 0.1.
"""
import os
import sys

import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "session_3_1"))
from run_query import connect_to_repo, find_repo_root  # noqa: E402

# ---- paste your Lab query 2 here --------------------------------------
LAG_QUERY = """

"""
# ------------------------------------------------------------------------

EVENTS_VIEW = """
CREATE OR REPLACE VIEW events AS
SELECT *,
       CAST(strptime(event_date, '%Y%m%d') AS DATE) AS report_date
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'})
"""


def pandas_side():
    """Week 2's way: serious reports per quarter, then pct_change()."""
    path = os.path.join(find_repo_root(), "data", "raw",
                        "adverse_events_10k.csv")
    df = pd.read_csv(path, dtype={"safety_report_id": str, "serious": str,
                                  "patient_age_unit": str,
                                  "event_date": str})
    df["quarter"] = pd.to_datetime(df["event_date"],
                                   format="%Y%m%d").dt.to_period("Q")
    serious = df[df["serious"] == "1"].groupby("quarter").size()
    out = (serious.pct_change() * 100).round(1).rename("pandas_pct")
    out.index = out.index.start_time.date
    return out


def sql_side():
    con = connect_to_repo()
    con.execute(EVENTS_VIEW)
    result = con.sql(LAG_QUERY.strip().rstrip(";")).df()
    missing = {"qtr", "pct_change"} - set(result.columns)
    if missing:
        sys.exit(f"Your query has no column(s) named {sorted(missing)}. "
                 "Name them with AS, e.g. ... AS qtr, ... AS pct_change.")
    if pd.api.types.is_string_dtype(result["qtr"]):
        sys.exit("qtr must be the quarter's first day as a DATE, e.g. "
                 "CAST(date_trunc('quarter', report_date) AS DATE) AS qtr, "
                 f"not a label such as {result['qtr'].iloc[0]!r}.")
    result["qtr"] = pd.to_datetime(result["qtr"]).dt.date
    return (result.set_index("qtr")["pct_change"].astype(float)
            .round(1).rename("sql_pct"))


if __name__ == "__main__":
    if not LAG_QUERY.strip():
        sys.exit("LAG_QUERY is empty: paste your Lab query 2 into it first.")
    both = pd.concat([sql_side(), pandas_side()], axis=1)
    # Two correct calculations can round to values 0.1 apart: pandas works
    # out (new / old - 1) * 100 and SQL often 100.0 * (new - old) / old, and
    # in floating point these can land either side of a ...5 boundary.
    same = (((both["sql_pct"] - both["pandas_pct"]).abs() <= 0.1 + 1e-9)
            | (both["sql_pct"].isna() & both["pandas_pct"].isna()))
    both["result"] = same.map({True: "MATCH", False: "DIFFERENT"})
    print(both.to_string())
    print()
    print(f"{int(same.sum())} of {len(both)} quarters match.")
