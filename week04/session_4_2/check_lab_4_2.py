"""Check the Session 4.2 Lab: the PharmaFlow Foundation repository, tidied.

Run from any folder inside your pharmaflow-ai repo, after the pull request
is merged and v0.2 is tagged and pushed:

    python week04/session_4_2/check_lab_4_2.py

It reads what is committed on main (not your working folder), then checks
out v0.2 into a temporary folder and runs the pipeline and the SQL library
there, exactly as a stranger who clones the repo would. Nothing in your
repository is changed; the temporary folder is deleted at the end.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

LINK = re.compile(r"!?\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
TOP_FILES = {"README.md", "requirements.txt", ".gitignore", "LICENSE"}
MUST_IGNORE = ["data/processed/foundation/raw_reports.json",
               "data/processed/foundation/events_clean.csv",
               "data/processed/foundation/events.parquet",
               "openfda_raw_pull.json", "data/raw/openfda_raw_pull_2.json",
               ".env", "scripts/__pycache__/x.pyc",
               "notebooks/.ipynb_checkpoints/x.ipynb"]
MUST_KEEP = ["data/processed/foundation/top10_drugs.parquet",
             "data/processed/charts/foundation_5_charts.png"]


def git(repo, *args):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True,
                       text=True)
    return r.returncode == 0, r.stdout


def repo_root():
    ok, top = git(".", "rev-parse", "--show-toplevel")
    if not ok:
        sys.exit("Run this from inside your pharmaflow-ai repository.")
    top = top.strip()
    m = re.search(r"/week04/session_4_2/practice/", top + "/")
    return top[:m.start()] if m else top


def main():
    repo = repo_root()
    git(repo, "fetch", "-q", "origin", "--tags")
    ok, listing = git(repo, "ls-tree", "-r", "--name-only", "origin/main")
    if not ok:
        sys.exit("Cannot read origin/main: has the branch been pushed?")
    files = set(listing.splitlines())
    folders = {p for f in files for p in _parents(f)}
    show = lambda path: git(repo, "show", f"origin/main:{path}")[1]  # noqa: E731
    results = []

    def check(label, passed, detail=""):
        results.append(passed)
        print(("PASS  " if passed else "FAIL  ") + label
              + (f"  ({detail})" if detail and not passed else ""))

    # 1-3: folders, library, notebook
    missing = [d for d in ("scripts", "queries", "notebooks", "data")
               if d not in folders]
    check("scripts/, queries/, notebooks/ and data/ are on main", not missing,
          "missing: " + ", ".join(missing))
    sql = sorted(f for f in files if f.startswith("queries/")
                 and f.endswith(".sql"))
    check("queries/ holds the SQL library (10 .sql files)", len(sql) >= 10,
          f"{len(sql)} .sql files")
    charts = 0
    nbs = [f for f in files if f.startswith("notebooks/")
           and f.endswith(".ipynb")]
    for f in nbs:
        try:
            nb = json.loads(show(f))
            charts = max(charts, sum("image/png" in o.get("data", {})
                                     for c in nb.get("cells", [])
                                     for o in c.get("outputs", [])))
        except ValueError:
            pass
    check("a notebook in notebooks/ is saved with its five charts",
          charts >= 5, f"most charts in one notebook: {charts}")

    # 4-6: README
    readme = show("README.md") if "README.md" in files else ""
    lines = readme.splitlines()
    needed = [readme.startswith("# "), len(re.findall(r"^## ", readme, re.M)) >= 3,
              "pip install -r requirements.txt" in readme,
              "scripts/ingest.py" in readme, "![" in readme]
    check("README: title, sections, setup, how to run, a picture",
          all(needed), "title / 3 sections / pip install / ingest.py / image: "
          + "".join("y" if n else "n" for n in needed))
    ok, url = git(repo, "config", "--get", "remote.origin.url")
    m = re.search(r"github\.com[:/]([^/\s]+)/([^/.\s]+)", url.strip())
    badge = False
    if m:
        pat = (r"nbviewer\.org/github/" + re.escape(m.group(1)) + "/"
               + re.escape(m.group(2)) + r"/blob/main/(notebooks/[^)\s]+\.ipynb)")
        found = re.findall(pat, readme)
        badge = any(f in files for f in found)
    check("README has an nbviewer badge for this repository's notebook", badge)
    broken, in_code = [], False
    for number, line in enumerate(lines, start=1):
        if line.lstrip().startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            continue
        for target in LINK.findall(line):
            if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or \
                    target.startswith("#"):
                continue
            path = os.path.normpath(target.split("#")[0].split("?")[0])
            path = path.lstrip("/")
            if path not in files and path not in folders:
                broken.append(f"line {number}: {target}")
    check("every README link and image points to a committed file",
          bool(readme) and not broken, "; ".join(broken[:3]))

    # 7-10: what is committed
    gi = tempfile.NamedTemporaryFile("w", delete=False, suffix=".gitignore")
    gi.write(show(".gitignore"))
    gi.close()
    def ignored(p):  # noqa: E306
        r = subprocess.run(["git", "-C", repo, "-c",
                            f"core.excludesFile={gi.name}", "check-ignore",
                            "-q", "--no-index", p], capture_output=True)
        return r.returncode == 0
    wrong = [p for p in MUST_IGNORE if not ignored(p)]
    wrong += [p + " (should not be ignored)" for p in MUST_KEEP if ignored(p)]
    check(".gitignore keeps out pipeline files, raw pulls, secrets, caches",
          not wrong, "; ".join(wrong[:3]))
    committed_wrong = [f for f in files if ignored(f)]
    keep = [p for p in MUST_KEEP if p not in files]
    os.unlink(gi.name)
    check("nothing ignored is still tracked; the top-10 answer and the chart "
          "page are", not committed_wrong and not keep,
          "; ".join((committed_wrong + [k + " not committed" for k in keep])[:3]))
    top = sorted(f for f in files if "/" not in f and f not in TOP_FILES)
    check("the top level holds only README, requirements.txt, .gitignore and "
          "folders", not top, ", ".join(top))

    # 11: tag
    ok_tag, tag_commit = git(repo, "rev-parse", "-q", "--verify", "v0.2^{commit}")
    tag_commit = tag_commit.strip()
    on_main = ok_tag and git(repo, "merge-base", "--is-ancestor", tag_commit,
                             "origin/main")[0]
    merge = ok_tag and len(git(repo, "rev-list", "--parents", "-n", "1",
                               tag_commit)[1].split()) == 3
    _, tag_object = git(repo, "rev-parse", "-q", "--verify", "v0.2")
    _, remote = git(repo, "ls-remote", "--tags", "origin", "v0.2")
    pushed = ok_tag and bool(tag_object.strip()) and tag_object.strip() in remote
    check("v0.2 is the pull-request merge on main, and is on GitHub",
          bool(on_main and merge and pushed),
          "tag missing" if not ok_tag else
          "not on main" if not on_main else
          "not a merge commit" if not merge else "not pushed")

    # 12: a fresh copy of v0.2
    fresh_ok, why = False, "no tag"
    if ok_tag:
        with tempfile.TemporaryDirectory() as tmp:
            wt = os.path.join(tmp, "v0.2")
            git(repo, "worktree", "add", "-q", "--detach", wt, "v0.2")
            try:
                ok_req, req = run_py(wt, "week04/session_4_2/check_requirements.py")
                outs = [run_py(wt, f"scripts/{s}.py") for s in
                        ("ingest", "clean", "store_and_query")]
                lib = run_py(wt, "week03/session_3_3/run_library.py")
                fresh_ok = ("requirements.txt OK" in req
                            and all(o[0] for o in outs)
                            and "Pipeline OK" in outs[-1][1]
                            and "Library OK" in lib[1])
                why = ("requirements.txt" if "requirements.txt OK" not in req
                       else "pipeline" if "Pipeline OK" not in outs[-1][1]
                       else "library")
            finally:
                git(repo, "worktree", "remove", "--force", wt)
    check("a fresh copy of v0.2: requirements OK, Pipeline OK, Library OK",
          fresh_ok, f"failed at: {why}")
    print(f"\n{sum(results)} of {len(results)} checks passed")


def run_py(folder, script):
    r = subprocess.run([sys.executable, script], cwd=folder,
                       capture_output=True, text=True)
    return r.returncode == 0, r.stdout + r.stderr


def _parents(path):
    while "/" in path:
        path = path.rsplit("/", 1)[0]
        yield path


if __name__ == "__main__":
    main()
