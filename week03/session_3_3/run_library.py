"""Run the whole PharmaFlow SQL library and check it.

Put this file in week03/session_3_3/ and run it from the repo root:

    python week03/session_3_3/run_library.py

or from week03/session_3_3/:

    python run_library.py

For every file NN_*.sql in week03/session_3_3/sql_library/, in order, it
  1. checks the comment block at the top has all six labels
     (Question, Asked by, Source, Output, Checked, Notes), and that
     every COPY writes through repo_file() (a plain path works from
     one folder only),
  2. runs the file with run_query.py (Session 3.1), hiding the printed
     tables (run one file with run_query.py to see its answer),
  3. checks the file wrote data/processed/library/<same name>.parquet
     and counts its rows.
The last line says whether the whole library passed.
"""
import contextlib
import io
import os
import re
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
from run_query import connect_to_repo, run_sql_file  # noqa: E402

LIBRARY = os.path.join(REPO_ROOT, "week03", "session_3_3", "sql_library")
OUTPUT = os.path.join(REPO_ROOT, "data", "processed", "library")
LABELS = ["Question", "Asked by", "Source", "Output", "Checked", "Notes"]


def missing_labels(sql_path):
    """The labels that do not appear in the file's first comment lines."""
    with open(sql_path, encoding="utf-8") as f:
        top = []
        for line in f:
            if not line.startswith("--"):
                break
            top.append(line)
    text = "".join(top)
    return [label for label in LABELS if f"-- {label}" not in text]


def plain_copy_paths(sql_path):
    """True if a COPY writes to a quoted path instead of repo_file(...)."""
    with open(sql_path, encoding="utf-8") as f:
        code = "".join(line.split("--")[0] + "\n" for line in f)
    return re.search(r"\bTO\s*'", code, flags=re.IGNORECASE) is not None


def main():
    if not os.path.isdir(LIBRARY):
        sys.exit(f"No folder {LIBRARY}: create it and put your .sql files in it")
    os.makedirs(OUTPUT, exist_ok=True)  # COPY creates files, not folders
    files = sorted(f for f in os.listdir(LIBRARY)
                   if f.endswith(".sql") and f[:2].isdigit())
    print(f"{len(files)} files in week03/session_3_3/sql_library/\n")
    problems = 0
    for name in files:
        stem = name[:-4]
        parquet = os.path.join(OUTPUT, stem + ".parquet")
        if os.path.exists(parquet):
            os.remove(parquet)  # so an old file cannot hide a broken one
        notes = []
        gaps = missing_labels(os.path.join(LIBRARY, name))
        if gaps:
            notes.append("header lacks " + ", ".join(gaps))
        if plain_copy_paths(os.path.join(LIBRARY, name)):
            notes.append("COPY to a plain path: use repo_file()")
        con = connect_to_repo()
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                run_sql_file(os.path.join(LIBRARY, name), con)
        except Exception as error:  # report it and carry on
            notes.append("SQL error: " + str(error).splitlines()[0][:60])
        if os.path.exists(parquet):
            rows = con.sql(f"SELECT COUNT(*) FROM '{parquet}'").fetchall()[0][0]
            result = f"{rows:>4} row" + ("s" if rows != 1 else " ")
        else:
            result = "  no file"
            notes.append(f"did not write data/processed/library/{stem}.parquet")
        problems += bool(notes)
        status = "OK  " if not notes else "FIX "
        print(f"{status} {stem:<28} {result}  {'; '.join(notes)}".rstrip())
    print()
    if files and not problems:
        print(f"Library OK: {len(files)} files, {len(files)} Parquet outputs "
              "in data/processed/library/")
    else:
        print(f"{problems} file(s) to fix" if files else "No .sql files found")


if __name__ == "__main__":
    main()
