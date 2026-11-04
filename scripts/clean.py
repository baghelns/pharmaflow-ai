"""PharmaFlow Foundation pipeline, step 2 of 3: clean the raw reports.

Run from any folder inside the pharmaflow-ai repo, after ingest.py:

    python scripts/clean.py

Reads  data/processed/foundation/raw_reports.json (from ingest.py).
Writes data/processed/foundation/events_clean.csv, one row per usable
report. The rules, each from an earlier session:
  - usable = exactly one suspect drug and a first reaction (Session 1.3);
  - keep the age's unit and add age_years (Session 2.1);
  - IDs, codes and dates stay text (Session 2.1);
  - a report ID that appears twice is a true duplicate: keep the first;
  - rows identical apart from the ID are flagged possible_duplicate,
    not deleted: a person decides (Session 2.1, Exercise 3).
"""
import json
import os

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
            raise FileNotFoundError(
                f"No '{marker_folder}' folder above {os.getcwd()}")
        current = parent


REPO_ROOT = find_repo_root()
FOLDER = os.path.join(REPO_ROOT, "data", "processed", "foundation")
RAW_FILE = os.path.join(FOLDER, "raw_reports.json")
OUT_FILE = os.path.join(FOLDER, "events_clean.csv")

# openFDA patientonsetageunit codes: 800 decade ... 805 hour (drugevent.yaml)
YEARS_PER_UNIT = {"800": 10.0, "801": 1.0, "802": 1 / 12, "803": 7 / 365.25,
                  "804": 1 / 365.25, "805": 1 / 8766}


def flatten_record(raw_record):
    """One flat row for a usable report, or None (Session 1.3, plus the
    age unit from Session 2.1)."""
    patient = raw_record.get("patient", {})
    suspects = [d for d in patient.get("drug", [])
                if d.get("drugcharacterization") == "1"
                and d.get("medicinalproduct")]
    reactions = patient.get("reaction", [])
    if len(suspects) != 1:
        return None
    if not reactions or not reactions[0].get("reactionmeddrapt"):
        return None
    return {
        "safety_report_id": raw_record.get("safetyreportid"),
        "drug_name": suspects[0]["medicinalproduct"],
        "reaction": reactions[0]["reactionmeddrapt"],
        "serious": raw_record.get("serious"),
        "patient_age": patient.get("patientonsetage"),
        "patient_age_unit": patient.get("patientonsetageunit"),
        "country": raw_record.get("occurcountry"),
        "event_date": raw_record.get("receivedate"),
    }


def main():
    with open(RAW_FILE, encoding="utf-8") as f:
        raw = json.load(f)
    rows = [r for r in (flatten_record(x) for x in raw) if r is not None]
    events = pd.DataFrame(rows, dtype="str")      # every column as text

    # Ages in years: the number times its unit; blank if either is missing
    age = pd.to_numeric(events["patient_age"], errors="coerce")
    per_year = events["patient_age_unit"].map(YEARS_PER_UNIT)
    events["age_years"] = (age * per_year).round(1)

    # True duplicates: the same report ID twice. Keep the first.
    before = len(events)
    events = events.drop_duplicates(subset="safety_report_id", keep="first")
    repeated_ids = before - len(events)

    # Look-alikes: identical apart from the ID. Flag every member.
    other_columns = [c for c in events.columns
                     if c not in ("safety_report_id", "age_years")]
    events["possible_duplicate"] = events.duplicated(
        subset=other_columns, keep=False)

    events.to_csv(OUT_FILE, index=False)
    print(f"clean: {len(raw)} raw -> {len(rows)} usable "
          f"({len(raw) - len(rows)} without one suspect drug and a reaction)")
    print(f"clean: {repeated_ids} repeated report IDs removed; "
          f"{int(events['possible_duplicate'].sum())} rows flagged "
          "possible_duplicate (kept)")
    with_age = events["age_years"].notna().sum()
    with_country = events["country"].notna().sum()
    print(f"clean: age known for {with_age} of {len(events)}; "
          f"country known for {with_country}")
    print(f"clean: wrote data/processed/foundation/events_clean.csv "
          f"({len(events)} rows)")


if __name__ == "__main__":
    main()
