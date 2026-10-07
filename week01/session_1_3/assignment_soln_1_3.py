#Assignment 1 — Does Page Size Change the Answer?

import csv, os, sys, time, json
import requests
 
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
sys.path.insert(0, os.path.join(REPO_ROOT, "week01", "session_1_3"))
from practice_api_server import start_server
 
server, PRACTICE_URL = start_server()
time.sleep(0.3)  # let the background server thread come up
 
def fetch_page(skip, limit=100, base_url=PRACTICE_URL, max_retries=3):
    """Session 1.3's retry-safe fetch_page(): retry a 429 with backoff."""
    for attempt in range(max_retries):
        response = requests.get(base_url, params={"limit": limit, "skip": skip})
        if response.status_code == 200:
            return response.json().get("results", [])
        if response.status_code == 429:
            time.sleep(2 ** attempt)
            continue
        response.raise_for_status()
    raise RuntimeError(f"Still rate-limited after {max_retries} retries (skip={skip}).")
def fetch_all_pages_counted(total_records, page_size, base_url=PRACTICE_URL):
    """Like Session 1.3's fetch_all_pages(), but also returns how many
    non-empty pages it took. Returns (records, pages_used)."""
    all_results, skip, pages = [], 0, 0
    while len(all_results) < total_records:
        page = fetch_page(skip, limit=page_size, base_url=base_url)
        if not page:
            break
        all_results.extend(page)
        pages += 1
        skip += page_size
    return all_results[:total_records], pages
 
baseline_ids = None
for page_size in (50, 100, 150):
    records, pages = fetch_all_pages_counted(300, page_size)
    ids = [r["safetyreportid"] for r in records]
    if baseline_ids is None:
        baseline_ids = ids
    print(f"page_size={page_size:<4} pages={pages}  records={len(records)}  "
          f"last id={ids[-1]}  same ids, same order as first run: {ids == baseline_ids}")
 
server.shutdown()


# Assignment 2 — One Row per Reaction

import csv, os, sys, time, json
import requests
 
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
sys.path.insert(0, os.path.join(REPO_ROOT, "week01", "session_1_3"))
from practice_api_server import start_server
 
server, PRACTICE_URL = start_server()
time.sleep(0.3)  # let the background server thread come up
 
def fetch_page(skip, limit=100, base_url=PRACTICE_URL, max_retries=3):
    """Session 1.3's retry-safe fetch_page(): retry a 429 with backoff."""
    for attempt in range(max_retries):
        response = requests.get(base_url, params={"limit": limit, "skip": skip})
        if response.status_code == 200:
            return response.json().get("results", [])
        if response.status_code == 429:
            time.sleep(2 ** attempt)
            continue
        response.raise_for_status()
    raise RuntimeError(f"Still rate-limited after {max_retries} retries (skip={skip}).")
def flatten_reactions(raw_record):
    """Return one flat row PER REACTION for a usable record (exactly one
    suspect drug and a non-empty first reaction), or [] otherwise.
    Never raises, whatever shape raw_record is."""
    try:
        patient = raw_record.get("patient", {})
        suspects = [
            d for d in patient.get("drug", [])
            if d.get("drugcharacterization") == "1" and d.get("medicinalproduct")
        ]
        reactions = patient.get("reaction", [])
        if len(suspects) != 1 or not reactions or not reactions[0].get("reactionmeddrapt"):
            return []
        return [
            {
                "safety_report_id": raw_record.get("safetyreportid"),
                "drug_name": suspects[0]["medicinalproduct"],
                "reaction": rx["reactionmeddrapt"],
            }
            for rx in reactions
            if rx.get("reactionmeddrapt")
        ]
    except (AttributeError, TypeError, IndexError):
        return []
 
raw = []
skip = 0
while len(raw) < 300:
    page = fetch_page(skip)
    if not page:
        break
    raw.extend(page)
    skip += 100
 
rows = [row for r in raw for row in flatten_reactions(r)]
report_ids = {row["safety_report_id"] for row in rows}
print(f"reaction-level rows: {len(rows)}  from {len(report_ids)} distinct reports")
 
out_dir = os.path.join(REPO_ROOT, "data", "processed")
os.makedirs(out_dir, exist_ok=True)
out_file = os.path.join(out_dir, "adverse_events_reactions_from_api.csv")
with open(out_file, "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=["safety_report_id", "drug_name", "reaction"])
    writer.writeheader()
    writer.writerows(rows)
with open(out_file, newline="") as f:
    reread = list(csv.DictReader(f))
print("re-read rows from CSV:", len(reread), "| first row equals in-memory first row:", reread[0] == rows[0])
 
def top3(terms):
    counts = {}
    for t in terms:
        counts[t] = counts.get(t, 0) + 1
    return sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[:3]
 
print("top 3, every reaction:     ", top3(row["reaction"] for row in rows))
first_only = []
for r in raw:
    reaction_rows = flatten_reactions(r)
    if reaction_rows:
        first_only.append(reaction_rows[0]["reaction"])
print("top 3, first reaction only:", top3(first_only))
 
server.shutdown()

#Assignment 3 — Retry Only What Can Clear Up

import csv, os, sys, time, json
import requests
 
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
sys.path.insert(0, os.path.join(REPO_ROOT, "week01", "session_1_3"))
from practice_api_server import start_server
 
server, PRACTICE_URL = start_server()
time.sleep(0.3)  # let the background server thread come up
 
def fetch_page(skip, limit=100, base_url=PRACTICE_URL, max_retries=3):
    """Session 1.3's retry-safe fetch_page(): retry a 429 with backoff."""
    for attempt in range(max_retries):
        response = requests.get(base_url, params={"limit": limit, "skip": skip})
        if response.status_code == 200:
            return response.json().get("results", [])
        if response.status_code == 429:
            time.sleep(2 ** attempt)
            continue
        response.raise_for_status()
    raise RuntimeError(f"Still rate-limited after {max_retries} retries (skip={skip}).")
def fetch_page_resilient(skip, limit=100, base_url=PRACTICE_URL,
                         max_attempts=3, base_wait=1, timeout=5):
    """Fetch one page, retrying ONLY failures that can plausibly clear up:
    a 429, a 5xx, a connection error or a timeout. Any other error status
    (400, 404, ...) is raised immediately -- retrying cannot fix a bad
    request. Returns (results, attempts_used). Raises RuntimeError naming
    the attempt count if every attempt fails."""
    last_problem = None
    for attempt in range(1, max_attempts + 1):
        try:
            response = requests.get(
                base_url, params={"limit": limit, "skip": skip}, timeout=timeout)
        except (requests.ConnectionError, requests.Timeout) as exc:
            last_problem = type(exc).__name__
        else:
            if response.status_code == 200:
                return response.json().get("results", []), attempt
            if response.status_code == 429 or 500 <= response.status_code < 600:
                last_problem = f"HTTP {response.status_code}"
            else:
                response.raise_for_status()  # a 4xx: do NOT retry
        if attempt < max_attempts:
            time.sleep(base_wait * 2 ** (attempt - 1))
    raise RuntimeError(
        f"gave up after {max_attempts} attempts (skip={skip}); last problem: {last_problem}")
 
# Check 1: the practice server rate-limits skip=200 once -> succeeds on attempt 2.
results, attempts = fetch_page_resilient(200)
print(f"check 1 (429 at skip=200): {len(results)} records, attempts used = {attempts}")
 
# Check 2: a wrong URL path is a 404 -> must fail immediately, no retries.
t0 = time.time()
try:
    fetch_page_resilient(0, base_url=PRACTICE_URL.replace("event", "nope"))
except requests.HTTPError as exc:
    print(f"check 2 (404): raised HTTPError at once, status {exc.response.status_code}, "
          f"fast = {time.time() - t0 < 0.5}")
 
# Check 3: nothing is listening on this port -> retries, then a clear error.
try:
    fetch_page_resilient(0, base_url="http://127.0.0.1:8799/drug/event.json", base_wait=0.1)
except RuntimeError as exc:
    print("check 3 (connection refused):", exc)
 
server.shutdown()


# Trainer-only extra check: a throwaway server that answers 503 twice, then 200.
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
 
class Flaky(BaseHTTPRequestHandler):
    hits = 0
    def log_message(self, *a): pass
    def do_GET(self):
        Flaky.hits += 1
        if Flaky.hits <= 2:
            self.send_response(503); self.end_headers(); return
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.end_headers(); self.wfile.write(b'{"results": [{"ok": 1}]}')
 
stub = HTTPServer(("127.0.0.1", 8798), Flaky)
threading.Thread(target=stub.serve_forever, daemon=True).start()
results, attempts = fetch_page_resilient(0, base_url="http://127.0.0.1:8798/x", base_wait=0.1)
print("check 4 (503, 503, 200):", results, "attempts used =", attempts)
stub.shutdown(); stub.server_close()
