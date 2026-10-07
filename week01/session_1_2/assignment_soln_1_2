
########################################
#Assignment 1 -- Severity Summary, Saved for the Dashboard

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
DATA_FILE = os.path.join(
    REPO_ROOT, "data", "raw", "adverse_events_100.json")
with open(DATA_FILE) as f:
    records = json.load(f)

def count_by_severity(records):
    """Return a dict with counts of serious vs non-serious records."""
    counts = {"serious": 0, "non_serious": 0}
    for r in records:
        if r.get("serious") == "1":
            counts["serious"] += 1
        else:
            counts["non_serious"] += 1
    return counts

summary = count_by_severity(records)
print(summary)

OUT = os.path.join(REPO_ROOT, "data", "processed", "severity_summary.json")
with open(OUT, "w") as f:
    json.dump(summary, f, indent=2)
with open(OUT) as f:
    reloaded = json.load(f)
print("Reloaded equals original:", reloaded == summary)


#####################################
# Assignment 2 -- Serious-Event Rate by Business Region


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
DATA_FILE = os.path.join(
    REPO_ROOT, "data", "raw", "adverse_events_100.json")
LOOKUP_FILE = os.path.join(REPO_ROOT, "data", "raw", "country_codes.csv")
with open(DATA_FILE) as f:
    records = json.load(f)

import csv

def load_country_lookup(filepath):
    lookup = {}
    with open(filepath, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            lookup[row["country_code"]] = row
    return lookup

def enrich_with_country_info(records, lookup):
    enriched = []
    for r in records:
        new_r = dict(r)
        info = lookup.get(new_r.get("country"))
        if info:
            new_r["business_region"] = info["business_region"]
        else:
            new_r["business_region"] = "UNKNOWN"
        enriched.append(new_r)
    return enriched

def region_serious_rate(records, lookup):
    """Return {region: (serious_count, total_count, rate_pct)}. Never
    crashes on a region with zero records."""
    enriched = enrich_with_country_info(records, lookup)
    totals, serious = {}, {}
    for r in enriched:
        region = r["business_region"]
        totals[region] = totals.get(region, 0) + 1
        if r.get("serious") == "1":
            serious[region] = serious.get(region, 0) + 1
    result = {}
    for region, total in totals.items():
        s = serious.get(region, 0)
        rate = round(100 * s / total, 1) if total else 0.0
        result[region] = (s, total, rate)
    return result

lookup = load_country_lookup(LOOKUP_FILE)
rates = region_serious_rate(records, lookup)
for region, (s, total, rate) in sorted(
        rates.items(), key=lambda x: (-x[1][2], -x[1][1])):
    print(f"{region:<15} {s}/{total} = {rate}%")


    ###############################################
    ## Assignment 3 — One Reusable Function, Any File

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
DATA_FILE = os.path.join(
    REPO_ROOT, "data", "raw", "adverse_events_100.json")
with open(DATA_FILE) as f:
    records = json.load(f)

def drug_reaction_index(records):
    """Return a dict mapping each drug_name to a list of its DISTINCT
    reactions, in first-seen order. Never crashes regardless of what is
    or isn't present on a given record."""
    index = {}
    for r in records:
        drug = r.get("drug_name")
        reaction = r.get("reaction")
        if not drug or not reaction:
            continue
        if drug not in index:
            index[drug] = []
        if reaction not in index[drug]:
            index[drug].append(reaction)
    return index

idx = drug_reaction_index(records)
print("Distinct drugs:", len(idx))
print("LYRICA ->", idx.get("LYRICA"))

OUT = os.path.join(
    REPO_ROOT, "data", "processed", "drug_reaction_index.json")
with open(OUT, "w") as f:
    json.dump(idx, f, indent=2)
with open(OUT) as f:
    reloaded = json.load(f)
print("Reloaded equals original:", reloaded == idx)
