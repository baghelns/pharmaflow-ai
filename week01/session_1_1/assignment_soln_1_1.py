#Assignment 1 — Country Tally

import json, os


def find_repo_root(marker_folder="data", start=None):
    # Search upward until we find the folder that contains data/ --
    # that only exists at the repo root, so this works no matter
    # which folder happened to be open or which file this runs from.
    current = os.path.abspath(start or os.getcwd())
    while True:
        if os.path.isdir(os.path.join(current, marker_folder)):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            raise FileNotFoundError("No data folder found above here.")
        current = parent


REPO_ROOT = find_repo_root()
DATA_FILE = os.path.join(REPO_ROOT, "data", "raw", "adverse_events_100.json")
with open(DATA_FILE) as f:
    records = json.load(f)


country_counts = {}
for r in records:
    country = r.get("country", "UNKNOWN")
    if country not in country_counts:
        country_counts[country] = [0, 0]
    country_counts[country][0] += 1
    if r.get("serious") == "1":
        country_counts[country][1] += 1


for country, (total, serious) in sorted(
        country_counts.items(), key=lambda x: x[1][0], reverse=True):
    print(f"{country:<6} total={total:<4} serious={serious}")


## Assignment 2 — Age, Honestly Reported
import json, os


def find_repo_root(marker_folder="data", start=None):
    # Search upward until we find the folder that contains data/ --
    # that only exists at the repo root, so this works no matter
    # which folder happened to be open or which file this runs from.
    current = os.path.abspath(start or os.getcwd())
    while True:
        if os.path.isdir(os.path.join(current, marker_folder)):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            raise FileNotFoundError("No data folder found above here.")
        current = parent


REPO_ROOT = find_repo_root()
DATA_FILE = os.path.join(REPO_ROOT, "data", "raw", "adverse_events_100.json")
with open(DATA_FILE) as f:
    records = json.load(f)


serious_events = [r for r in records if r.get("serious") == "1"]
ages = []
excluded = 0
for r in serious_events:
    age_raw = r.get("patient_age")
    if age_raw is None:
        excluded += 1
        continue
    try:
        ages.append(int(age_raw))
    except (ValueError, TypeError):
        excluded += 1


avg_age = sum(ages) / len(ages) if ages else None
print(f"Average age among serious events with reported age: {avg_age:.1f}")
print(f"Based on {len(ages)} records")
print(f"{excluded} serious records excluded (missing patient_age)")
import json, os


def find_repo_root(marker_folder="data", start=None):
    # Search upward until we find the folder that contains data/ --
    # that only exists at the repo root, so this works no matter
    # which folder happened to be open or which file this runs from.
    current = os.path.abspath(start or os.getcwd())
    while True:
        if os.path.isdir(os.path.join(current, marker_folder)):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            raise FileNotFoundError("No data folder found above here.")
        current = parent


REPO_ROOT = find_repo_root()
DATA_FILE = os.path.join(REPO_ROOT, "data", "raw", "adverse_events_100.json")
with open(DATA_FILE) as f:
    records = json.load(f)


serious_events = [r for r in records if r.get("serious") == "1"]
ages = []
excluded = 0
for r in serious_events:
    age_raw = r.get("patient_age")
    if age_raw is None:
        excluded += 1
        continue
    try:
        ages.append(int(age_raw))
    except (ValueError, TypeError):
        excluded += 1


avg_age = sum(ages) / len(ages) if ages else None
print(f"Average age among serious events with reported age: {avg_age:.1f}")
print(f"Based on {len(ages)} records")
print(f"{excluded} serious records excluded (missing patient_age)")


## Assignment 3 — One Function, Two Dimensions

import json, os


def find_repo_root(marker_folder="data", start=None):
    # Search upward until we find the folder that contains data/ --
    # that only exists at the repo root, so this works no matter
    # which folder happened to be open or which file this runs from.
    current = os.path.abspath(start or os.getcwd())
    while True:
        if os.path.isdir(os.path.join(current, marker_folder)):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            raise FileNotFoundError("No data folder found above here.")
        current = parent


REPO_ROOT = find_repo_root()
DATA_FILE = os.path.join(REPO_ROOT, "data", "raw", "adverse_events_100.json")
with open(DATA_FILE) as f:
    records = json.load(f)


def country_summary(records):
    summary = {}
    for r in records:
        country = r.get("country") or "UNKNOWN"
        if country not in summary:
            summary[country] = {
                "total_events": 0, "serious_events": 0, "reports_with_age": 0
            }
        summary[country]["total_events"] += 1
        if r.get("serious") == "1":
            summary[country]["serious_events"] += 1
        if r.get("patient_age") is not None:
            summary[country]["reports_with_age"] += 1
    return summary


summary = country_summary(records)
top3 = sorted(
    summary.items(), key=lambda x: x[1]["serious_events"], reverse=True
)[:3]
for country, data in top3:
    print(country, data)

