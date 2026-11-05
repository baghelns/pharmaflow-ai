"""
fetch_openfda_10k.py -- pull 10,000 real adverse-event reports from openFDA
for Week 2 (Session 2.1), spread evenly over 8 quarters: 2024 Q3 to 2026 Q2.

Why spread it out?  openFDA returns records in a clustered default order, so a
plain "first 10,000" pull can cover a narrow date range and a handful of drugs.
Week 2 needs quarter-over-quarter (QoQ) trends, so this script asks for the
same number of records from every month, and inside each month it reads from
four different positions (skip = 0, 6000, 12000, 18000) instead of one block.

  8 quarters x 1,250 records = 10,000
  each quarter = 3 months (417 + 417 + 416)
  each month   = 4 small requests (about 104 records each)
  total        = 96 requests -- well inside openFDA's no-key limits
                 (240 requests/minute, 1,000 requests/day)

What it saves:  the RAW API responses, untouched, in one compressed file:
  openfda_raw_10k.json.gz   (send this file back for curation)

Run it from a terminal in your Codespace:
  python fetch_openfda_10k.py

Standard library only -- no pip install needed.
"""

import gzip
import json
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

BASE_URL = os.environ.get("OPENFDA_BASE", "https://api.fda.gov") + "/drug/event.json"
OUTPUT_FILE = "openfda_raw_10k.json.gz"

# (year, quarter) -> 8 recent completed quarters
QUARTERS = [(2024, 3), (2024, 4), (2025, 1), (2025, 2),
            (2025, 3), (2025, 4), (2026, 1), (2026, 2)]
PER_QUARTER = 1250
SKIP_POSITIONS = [0, 6000, 12000, 18000]   # openFDA allows skip up to 25,000
PAUSE_SECONDS = 0.4                        # stay far below 240 requests/minute
MAX_ATTEMPTS = 5


def split_evenly(total, parts):
    """Split `total` into `parts` whole numbers that differ by at most 1."""
    base, extra = divmod(total, parts)
    return [base + 1 if i < extra else base for i in range(parts)]


def month_range(year, month):
    """First and last day of a month as YYYYMMDD strings."""
    first = f"{year}{month:02d}01"
    if month == 12:
        nxt = datetime(year + 1, 1, 1)
    else:
        nxt = datetime(year, month + 1, 1)
    last_day = (nxt - datetime(year, month, 1)).days
    return first, f"{year}{month:02d}{last_day:02d}"


def call_api(search, limit, skip):
    """One GET request with retry on 429 / 5xx. Returns (status, parsed_json)."""
    url = f"{BASE_URL}?search={search}&limit={limit}&skip={skip}"
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            with urllib.request.urlopen(url, timeout=60) as resp:
                return resp.status, json.loads(resp.read().decode("utf-8")), url
        except urllib.error.HTTPError as err:
            body = err.read().decode("utf-8", errors="replace")
            if err.code == 404:              # openFDA's way of saying "0 matches"
                return 404, {"error_body": body}, url
            if err.code == 429 or err.code >= 500:
                wait = 2 ** attempt
                print(f"    HTTP {err.code} -- waiting {wait}s, then retry "
                      f"{attempt}/{MAX_ATTEMPTS}")
                time.sleep(wait)
                continue
            print(f"\nStopped: HTTP {err.code} for {url}\n{body[:500]}")
            sys.exit(1)
        except urllib.error.URLError as err:
            wait = 2 ** attempt
            print(f"    Network problem ({err.reason}) -- waiting {wait}s, "
                  f"retry {attempt}/{MAX_ATTEMPTS}")
            time.sleep(wait)
    print(f"\nStopped: gave up after {MAX_ATTEMPTS} attempts on {url}")
    sys.exit(1)


def build_plan():
    """List every (month, search, chunk sizes) we will request."""
    plan = []
    for year, q in QUARTERS:
        months = [3 * (q - 1) + 1, 3 * (q - 1) + 2, 3 * (q - 1) + 3]
        for month, month_total in zip(months, split_evenly(PER_QUARTER, 3)):
            start, end = month_range(year, month)
            plan.append({
                "quarter": f"{year}-Q{q}",
                "month": f"{year}-{month:02d}",
                "search": f"receivedate:[{start}+TO+{end}]",
                "chunks": split_evenly(month_total, len(SKIP_POSITIONS)),
            })
    return plan


def main():
    plan = build_plan()
    needed_depth = SKIP_POSITIONS[-1] + max(max(p["chunks"]) for p in plan)

    # ---- Step 1: check every month has enough reports BEFORE downloading ----
    print("Step 1 of 2 -- checking how many reports openFDA has for each month")
    problems = []
    for p in plan:
        status, data, _ = call_api(p["search"], 1, 0)
        total = data["meta"]["results"]["total"] if status == 200 else 0
        p["available"] = total
        flag = "" if total >= needed_depth else "   <-- NOT ENOUGH"
        print(f"  {p['month']}: {total:>9,} reports{flag}")
        if total < needed_depth:
            problems.append(p["month"])
        time.sleep(PAUSE_SECONDS)

    if problems:
        print(f"\nStopped before downloading: {len(problems)} month(s) have fewer "
              f"than {needed_depth:,} reports in openFDA yet: {', '.join(problems)}")
        print("Copy everything printed above and send it back -- the date "
              "window will be shifted to quarters openFDA has fully loaded.")
        sys.exit(1)

    # ---- Step 2: download ----
    print(f"\nStep 2 of 2 -- downloading {len(plan) * len(SKIP_POSITIONS)} pages")
    pages, grand_total = [], 0
    for p in plan:
        month_count = 0
        for skip, limit in zip(SKIP_POSITIONS, p["chunks"]):
            status, data, url = call_api(p["search"], limit, skip)
            got = len(data.get("results", [])) if status == 200 else 0
            pages.append({"quarter": p["quarter"], "month": p["month"],
                          "skip": skip, "limit": limit, "url": url,
                          "http_status": status, "response": data})
            month_count += got
            time.sleep(PAUSE_SECONDS)
        grand_total += month_count
        print(f"  {p['quarter']}  {p['month']}: {month_count} records "
              f"(running total {grand_total:,})")

    bundle = {
        "pulled_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "source": BASE_URL,
        "quarters": [f"{y}-Q{q}" for y, q in QUARTERS],
        "month_totals_available": {p["month"]: p["available"] for p in plan},
        "pages": pages,
    }
    with gzip.open(OUTPUT_FILE, "wt", encoding="utf-8") as f:
        json.dump(bundle, f)

    size_mb = os.path.getsize(OUTPUT_FILE) / 1_000_000
    print(f"\nDone: {grand_total:,} records saved to {OUTPUT_FILE} ({size_mb:.1f} MB)")
    if grand_total != 10_000:
        print("Note: expected exactly 10,000 -- send the output above along "
              "with the file.")


if __name__ == "__main__":
    main()
