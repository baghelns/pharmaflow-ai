"""
One-time pull of raw OpenFDA drug-adverse-event records, for Session 1.2's
Lab task (which needs the pipeline proven on 1,000 records, not the 100 from
Session 1.1).

Run this from anywhere with real internet access (your Codespace terminal is
fine) -- it will NOT work from a restricted sandbox. Uses only the Python
standard library, so no pip install is needed.

No API key required for this volume (openFDA allows 1,000 requests/day per
IP without one; this script makes 60). Saves the RAW, unmodified API
response -- no cleaning/curating happens here on purpose, so nothing about
the real records gets lost or altered before a human/Claude looks at them.

Over-fetches on purpose: Session 1.1's 100-record curated file came from a
500-record raw pull (5x), because real records vary a lot in completeness
and a lookup-diversity cap (max repeats per drug) discards more on top of
that. 6,000 raw records here should comfortably curate down to 1,000+ clean,
diverse ones -- if it falls short, re-run with NUM_PAGES raised further.
"""
import json
import time
import urllib.request

BASE_URL = "https://api.fda.gov/drug/event.json"
PAGE_SIZE = 100       # openFDA's max per request
NUM_PAGES = 60         # 60 x 100 = 6,000 raw records to curate down from
OUTPUT_FILE = "openfda_raw_pull_session_1_2.json"

all_results = []
for page in range(NUM_PAGES):
    skip = page * PAGE_SIZE
    url = f"{BASE_URL}?limit={PAGE_SIZE}&skip={skip}"
    print(f"Fetching records {skip}-{skip + PAGE_SIZE}...")
    with urllib.request.urlopen(url, timeout=30) as resp:
        data = json.loads(resp.read().decode())
    all_results.extend(data.get("results", []))
    time.sleep(0.5)  # be polite to the API

with open(OUTPUT_FILE, "w") as f:
    json.dump(all_results, f, indent=2)

print(f"\nSaved {len(all_results)} raw records to {OUTPUT_FILE}")
print("Send this file back and it'll be curated into the 1,000-record Lab dataset.")
