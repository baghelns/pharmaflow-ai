"""PharmaFlow Foundation pipeline, step 1 of 3: pull raw reports from an API.

Run from any folder inside the pharmaflow-ai repo:

    python scripts/ingest.py               # Session 1.3's practice API: 300
    python scripts/ingest.py --live 1000   # the real openFDA API: 1,000

Writes data/processed/foundation/raw_reports.json: every record exactly as
the API returned it. Nothing is cleaned here; step 2 (clean.py) does that.
The practice API is a copy of real openFDA records that answers instantly
and sends one 429 ("too many requests") on purpose (Session 1.3).
"""
import json
import os
import sys
import time

import requests

LIVE_URL = "https://api.fda.gov/drug/event.json"
PAGE_SIZE = 100           # records per request (openFDA allows up to 1,000)
MAX_ATTEMPTS = 3          # tries per page before giving up


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
OUT_DIR = os.path.join(REPO_ROOT, "data", "processed", "foundation")
OUT_FILE = os.path.join(OUT_DIR, "raw_reports.json")


def fetch_page(base_url, skip, limit=PAGE_SIZE):
    """Return one page of raw records. A 429 is retried after 1, then 2
    seconds; any other error, or a third 429, stops the run."""
    params = {"limit": limit, "skip": skip}
    for attempt in range(1, MAX_ATTEMPTS + 1):
        response = requests.get(base_url, params=params, timeout=30)
        if response.status_code == 429:
            if attempt == MAX_ATTEMPTS:
                raise RuntimeError(
                    f"skip={skip}: still 429 after {MAX_ATTEMPTS} tries")
            wait = 2 ** (attempt - 1)
            print(f"  skip={skip}: 429, waiting {wait} s (try {attempt})")
            time.sleep(wait)
            continue
        if response.status_code == 404:
            return []                     # openFDA: no records past the end
        response.raise_for_status()       # anything else unexpected: stop
        return response.json().get("results", [])


def fetch_reports(base_url, target):
    """Fetch pages until `target` records or an empty page."""
    records, pages = [], 0
    while len(records) < target:
        page = fetch_page(base_url, skip=len(records),
                          limit=min(PAGE_SIZE, target - len(records)))
        if not page:
            break
        records.extend(page)
        pages += 1
        print(f"  page {pages}: {len(records)} records so far")
    return records


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--live":
        source, target = "openFDA live API", int(sys.argv[2])
        if not 1 <= target <= 25000:
            sys.exit("--live takes 1 to 25000: openFDA's skip stops at 25,000")
        records = fetch_reports(LIVE_URL, target)
    elif len(sys.argv) == 1:
        sys.path.insert(0, os.path.join(REPO_ROOT, "week01", "session_1_3"))
        try:
            from practice_api_server import start_server
        except ImportError:
            sys.exit("Need week01/session_1_3/practice_api_server.py "
                     "(Session 1.3).")
        source, target = "practice API (Session 1.3)", 300
        server, base_url = start_server()
        try:
            records = fetch_reports(base_url, target)
        finally:
            server.shutdown()             # always release the port
    else:
        sys.exit("Usage: python scripts/ingest.py [--live N]")

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT_FILE, "w", encoding="utf-8") as f:
        json.dump(records, f)
    print(f"ingest: {len(records)} raw records from the {source}")
    print("ingest: wrote data/processed/foundation/raw_reports.json")


if __name__ == "__main__":
    main()
