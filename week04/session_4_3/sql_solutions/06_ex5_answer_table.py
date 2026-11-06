"""Exercise 5: one line per business question, read from the committed
SQL library's Parquet answers. answer_table(repo) never raises: a missing
or unreadable file becomes a line that says so.
Run: python 06_ex5_answer_table.py <repo folder> [<repo folder> ...]"""
import os
import sys

import duckdb

LIB = "data/processed/library"
QUESTIONS = [
    ("Q1 top drug", "03_top10_drugs",
     "SELECT drug_name || ': ' || reports || ' reports' FROM t "
     "ORDER BY reports DESC, drug_name LIMIT 1"),
    ("Q2 quarter with fewest serious reports", "07_serious_by_quarter",
     "SELECT quarter_label || ': ' || serious_reports || ' serious' FROM t "
     "ORDER BY serious_reports, qtr LIMIT 1"),
    ("Q3 most often serious category", "06_reaction_categories",
     "SELECT reaction_category || ': ' || pct_serious || '% serious' FROM t "
     "ORDER BY pct_serious DESC, reaction_category LIMIT 1"),
    ("Q4 largest drug class", "05_drug_classes",
     "SELECT drug_class || ': ' || reports || ' reports' FROM t "
     "ORDER BY reports DESC, drug_class LIMIT 1"),
    ("Q5 bulk-submission days", "08_bulk_submissions",
     "SELECT count(*) || ' days, ' || coalesce(sum(reports), 0) "
     "|| ' reports' FROM t"),
]


def answer_table(repo):
    if not os.path.isdir(repo):
        return [f"{repo}: no such folder"]
    con = duckdb.connect()
    lines = []
    for label, name, sql in QUESTIONS:
        path = os.path.join(repo, LIB, name + ".parquet")
        if not os.path.isfile(path):
            lines.append(f"{label}: missing {LIB}/{name}.parquet")
            continue
        try:
            quoted = path.replace("'", "''")    # a ' in a folder name
            con.execute("CREATE OR REPLACE VIEW t AS SELECT * FROM "
                        f"read_parquet('{quoted}')")
            row = con.execute(sql).fetchall()
            answer = row[0][0] if row and row[0][0] is not None else "no rows"
        except duckdb.Error:
            answer = f"cannot read {LIB}/{name}.parquet"
        lines.append(f"{label}: {answer}")
    con.close()
    return lines


if __name__ == "__main__":
    for repo in sys.argv[1:]:
        print(f"== {repo}")
        for line in answer_table(repo):
            print("  " + line)
