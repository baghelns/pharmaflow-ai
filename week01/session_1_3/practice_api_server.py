"""
practice_api_server.py -- a small local stand-in for the real OpenFDA API,
for Session 1.3.

Why this exists: the real api.fda.gov is a shared, public, rate-limited
service. While you're still writing and debugging pagination and
retry logic, you don't want every test run to depend on network latency,
and you genuinely can't make the real API return a 429 on command to prove
your retry logic actually works -- rate limiting only fires when it fires.
This server solves both problems: it's instant, it's local, and it will
deliberately return a 429 exactly once, on a page you can predict, so your
retry logic has something real to prove itself against.

It is not fake data: /drug/event.json?limit=N&skip=M serves real, raw
OpenFDA adverse-event records (openfda_practice_sample.json, 300 of them,
served 100 per page = 3 pages; the live API allows up to 1,000 per request,
but a smaller page keeps pagination worth practicing) in the exact response
shape the live API uses -- {"results": [...]}. Code written against this
server is, field-for-field, the same code that works against the real,
live https://api.fda.gov/drug/event.json -- only the base URL changes.

Usage (see the Exercise Workbook's setup cell for the full pattern):
    from practice_api_server import start_server
    server, PRACTICE_URL = start_server()
    # ... use PRACTICE_URL as base_url in your fetch functions ...
    server.shutdown()
"""
import json
import os
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs


def find_repo_root(marker_folder="data", start=None):
    """Same reasoning as every other script in this repo: search upward
    until we find the folder that contains `data`, since that only exists
    at the repo root."""
    current = os.path.abspath(start or os.getcwd())
    while True:
        if os.path.isdir(os.path.join(current, marker_folder)):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            raise FileNotFoundError(
                f"Could not find a 'data' folder anywhere above {os.getcwd()}. "
                f"Make sure this script is somewhere inside the pharmaflow-ai repo."
            )
        current = parent


REPO_ROOT = find_repo_root()
SAMPLE_FILE = os.path.join(REPO_ROOT, "data", "raw", "openfda_practice_sample.json")

# Which skip value returns 429 the FIRST time it's requested, then succeeds
# on every retry after that -- lets retry/backoff logic be proven for real,
# on demand, instead of hoping the live API happens to rate-limit you.
RATE_LIMITED_SKIP = 200


class _Server(HTTPServer):
    """HTTPServer whose shutdown() also releases the port, so a notebook cell
    that starts the server can be re-run after shutdown() without hitting
    "Address already in use"."""
    def shutdown(self):
        super().shutdown()
        self.server_close()


class _Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # keep notebook/terminal output quiet

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path != "/drug/event.json":
            self.send_response(404)
            self.end_headers()
            return
        qs = parse_qs(parsed.query)
        limit = int(qs.get("limit", ["100"])[0])
        skip = int(qs.get("skip", ["0"])[0])

        if skip == RATE_LIMITED_SKIP and skip not in self.server.seen_skips:
            self.server.seen_skips.add(skip)
            self.send_response(429)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(
                {"error": {"code": "RATE_LIMIT", "message": "Too many requests"}}
            ).encode())
            return

        page = self.server.records[skip:skip + limit]
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"results": page}).encode())


def start_server(port=8765):
    """Start the practice server in a background thread and return
    (server, base_url). Call server.shutdown() when you're done with it."""
    with open(SAMPLE_FILE) as f:
        records = json.load(f)
    server = _Server(("127.0.0.1", port), _Handler)
    server.records = records
    server.seen_skips = set()
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base_url = f"http://127.0.0.1:{port}/drug/event.json"
    return server, base_url


if __name__ == "__main__":
    server, url = start_server()
    print(f"Practice API server running at {url}")
    print(f"Serving {len(server.records)} real raw OpenFDA records, 100 per page.")
    print(f"Page at skip={RATE_LIMITED_SKIP} returns 429 once, then succeeds.")
    print("Press Ctrl+C to stop.")
    try:
        while True:
            threading.Event().wait(3600)
    except KeyboardInterrupt:
        server.shutdown()
