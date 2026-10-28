"""Run every statement in a .sql file with DuckDB and print each result.

Usage, from any folder inside your pharmaflow-ai repo:

    python week03/session_3_1/run_query.py \
        week03/session_3_1/sql/01_warmup_canteen.sql

Paths inside the .sql files (such as 'data/raw/adverse_events_10k.csv')
are relative to the repo root. connect_to_repo() tells DuckDB to look
for them there, wherever you run from. From a notebook:

    from run_query import connect_to_repo, run_sql, run_sql_file
    con = connect_to_repo()
    run_sql_file("sql/01_warmup_canteen.sql", con)
    run_sql("SELECT * FROM menu", con)   # the tables are still there
"""
import os
import re
import sys

import duckdb

# The closing semicolon of a statement, plus any spaces and "--" comments
# after it. con.sql() needs the statement without them.
TERMINATOR = re.compile(r";(\s|--[^\n]*)*\Z")


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


def connect_to_repo():
    """Open a DuckDB connection that finds relative file paths, such as
    'data/raw/...', in the repo root, whatever folder you are in."""
    con = duckdb.connect()
    root = find_repo_root().replace("'", "''")  # quote-safe for SQL
    con.execute(f"SET file_search_path = '{root}'")
    return con


def run_sql(text, con=None):
    """Run each SQL statement in the string `text` in order and print
    every result that has rows. When there is more than one result, each
    gets a heading: -- Result 1, -- Result 2, ... Return the connection."""
    con = con or connect_to_repo()
    statements = duckdb.extract_statements(text)
    selects = [s for s in statements
               if s.type == duckdb.StatementType.SELECT]
    result_number = 0
    for statement in statements:
        if statement.type != duckdb.StatementType.SELECT:
            con.execute(statement.query)  # CREATE, INSERT: no rows to show
            continue
        result_number += 1
        if len(selects) > 1:
            print(f"-- Result {result_number}")
        query = TERMINATOR.sub("", statement.query.strip())
        con.sql(query).show(max_width=88, max_rows=60)
    return con


def run_sql_file(sql_path, con=None):
    """Run every statement in the .sql file sql_path, as run_sql does.
    Return the connection so you can keep querying."""
    with open(sql_path, encoding="utf-8") as f:
        return run_sql(f.read(), con)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: python run_query.py path/to/file.sql")
    run_sql_file(sys.argv[1])
