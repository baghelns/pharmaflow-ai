# Assignment 1 — Where Do Our Reports Come From?

import os
import pandas as pd
 
def find_repo_root(marker_folder="data", start=None):
    # Search upward until we find the folder that contains data/ --
    # that only exists at the repo root, so this works from any folder.
    current = os.path.abspath(start or os.getcwd())
    while True:
        if os.path.isdir(os.path.join(current, marker_folder)):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            raise FileNotFoundError("No data folder found above here.")
        current = parent
 
DATA_FILE = os.path.join(find_repo_root(), "data", "raw", "adverse_events_10k.csv")
TEXT_COLUMNS = {"safety_report_id": str, "serious": str,
                "patient_age_unit": str, "event_date": str}
df = pd.read_csv(DATA_FILE, dtype=TEXT_COLUMNS)
pd.set_option("display.width", 120)
 
countries = df["country"].fillna("Not reported")
coverage = pd.DataFrame({
    "reports": countries.value_counts(),
    "share_pct": (countries.value_counts(normalize=True) * 100).round(1),
})
print(coverage.head(8))
print()
print("distinct country codes (blanks excluded):", df["country"].nunique())
print("reports in the table add up to:", coverage["reports"].sum(), "of", len(df))


## Assignment 2 — Deaths Recorded as Not Serious?

import os
import pandas as pd
 
def find_repo_root(marker_folder="data", start=None):
    # Search upward until we find the folder that contains data/ --
    # that only exists at the repo root, so this works from any folder.
    current = os.path.abspath(start or os.getcwd())
    while True:
        if os.path.isdir(os.path.join(current, marker_folder)):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            raise FileNotFoundError("No data folder found above here.")
        current = parent
 
DATA_FILE = os.path.join(find_repo_root(), "data", "raw", "adverse_events_10k.csv")
TEXT_COLUMNS = {"safety_report_id": str, "serious": str,
                "patient_age_unit": str, "event_date": str}
df = pd.read_csv(DATA_FILE, dtype=TEXT_COLUMNS)
pd.set_option("display.width", 120)
 
deaths = df[df["reaction"] == "Death"]
print("reports whose first reaction is Death:", len(deaths))
print("seriousness among them:", deaths["serious"].value_counts(dropna=False).to_dict())
 
inconsistent = deaths[deaths["serious"] != "1"]
print()
print("Death reports NOT marked serious:", len(inconsistent))
print(inconsistent[["safety_report_id", "drug_name", "serious", "country", "event_date"]])


## Assignment 3 — How Many Reports Are About Children?

import os
import pandas as pd
 
def find_repo_root(marker_folder="data", start=None):
    # Search upward until we find the folder that contains data/ --
    # that only exists at the repo root, so this works from any folder.
    current = os.path.abspath(start or os.getcwd())
    while True:
        if os.path.isdir(os.path.join(current, marker_folder)):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            raise FileNotFoundError("No data folder found above here.")
        current = parent
 
DATA_FILE = os.path.join(find_repo_root(), "data", "raw", "adverse_events_10k.csv")
TEXT_COLUMNS = {"safety_report_id": str, "serious": str,
                "patient_age_unit": str, "event_date": str}
df = pd.read_csv(DATA_FILE, dtype=TEXT_COLUMNS)
pd.set_option("display.width", 120)
 
UNIT_TO_YEARS = {"800": 10, "801": 1, "802": 1 / 12,
                 "803": 7 / 365.25, "804": 1 / 365.25, "805": 1 / (24 * 365.25)}
age_years = df["patient_age"] * df["patient_age_unit"].map(UNIT_TO_YEARS)
 
naive_child = df["patient_age"] < 18
real_child = age_years < 18
print("under 18, treating every age as years:", naive_child.sum())
print("under 18, after converting units:     ", real_child.sum(),
      "of", age_years.notnull().sum(), "reports with a known age")
 
disagree = df[naive_child != real_child].assign(age_years=age_years.round(1))
print()
print("rows where the two answers disagree, by unit code:")
print(disagree["patient_age_unit"].value_counts())
print()
print("counted as children only by the naive version:", (naive_child & ~real_child).sum())
print("missed by the naive version:", (~naive_child & real_child).sum())
print(disagree.loc[~naive_child & real_child, ["drug_name", "patient_age", "patient_age_unit", "age_years"]])
print()
print("real under-18 reports by unit code:", df.loc[real_child, "patient_age_unit"].value_counts().to_dict())
