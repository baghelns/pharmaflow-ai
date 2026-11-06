"""Check the Session 4.3 Capstone: PharmaFlow Foundation v1.0.

Run from any folder inside your pharmaflow-ai repo, after the Findings
pull request is merged and v1.0 is tagged and pushed:

    python week04/session_4_3/check_capstone_4_3.py

It reads the README committed on main (not your working folder) and checks
its Findings section answers the five business questions with numbers and
links to committed evidence. Then it checks out v1.0 into a temporary
folder and runs the requirements check, the pipeline and the SQL library
there, as a stranger who clones the repo would. Nothing in your repository
is changed; the temporary folder is deleted at the end.
"""
import os
import re
import subprocess
import sys
import tempfile

LINK = re.compile(r"!?\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
# the evidence that answers each question (any one of them will do)
EVIDENCE = {
    1: ["queries/03_top10_drugs.sql", "data/processed/library/03_top10_drugs.parquet",
        "data/processed/foundation/top10_drugs.parquet",
        "data/processed/charts/lab1_top10_drugs.png"],
    2: ["queries/07_serious_by_quarter.sql",
        "data/processed/library/07_serious_by_quarter.parquet",
        "data/processed/charts/lab2_serious_share_quarter.png"],
    3: ["queries/06_reaction_categories.sql",
        "data/processed/library/06_reaction_categories.parquet",
        "data/processed/charts/lab3_heatmap.png"],
    4: ["queries/05_drug_classes.sql", "queries/09_rank_in_class.sql",
        "data/processed/library/05_drug_classes.parquet",
        "data/processed/library/09_rank_in_class.parquet",
        "data/processed/charts/lab5_age_by_class.png"],
    5: ["queries/02_missing_values.sql", "queries/08_bulk_submissions.sql",
        "data/processed/library/02_missing_values.parquet",
        "data/processed/library/08_bulk_submissions.parquet"],
}


def git(repo, *args):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True,
                       text=True)
    return r.returncode == 0, r.stdout


def repo_root():
    ok, top = git(".", "rev-parse", "--show-toplevel")
    if not ok:
        sys.exit("Run this from inside your pharmaflow-ai repository.")
    top = top.strip()
    m = re.search(r"/week04/session_4_[23]/practice/", top + "/")
    return top[:m.start()] if m else top


def findings(readme):
    """{question number: its text} from the README's ## Findings section."""
    part = re.split(r"^## Findings\b.*$", readme, maxsplit=1, flags=re.M)
    if len(part) < 2:
        return {}
    section = re.split(r"^## ", part[1], maxsplit=1, flags=re.M)[0]
    found = {}
    for m in re.finditer(r"^### Q([1-5])\b(.*?)(?=^### |\Z)", section,
                         flags=re.M | re.S):
        found[int(m.group(1))] = m.group(2)
    return found


def links(text):
    out = []
    for target in LINK.findall(text):
        if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or \
                target.startswith("#"):
            continue
        out.append(os.path.normpath(target.split("#")[0]).lstrip("/"))
    return out


def has_number(text):
    """A count or a percentage in the prose: link targets, quarter labels
    (2026 Q1) and question numbers do not count."""
    prose = re.sub(r"\]\([^)]*\)", "]", text)
    prose = re.sub(r"\b(19|20)\d\d Q[1-4]\b|\bQ[1-5]\b", "", prose)
    return re.search(r"\d", prose) is not None


def run_py(folder, script):
    r = subprocess.run([sys.executable, script], cwd=folder,
                       capture_output=True, text=True)
    return r.returncode == 0, r.stdout + r.stderr


def main():
    repo = repo_root()
    git(repo, "fetch", "-q", "origin", "--tags")
    ok, listing = git(repo, "ls-tree", "-r", "--name-only", "origin/main")
    if not ok:
        sys.exit("Cannot read origin/main: has the branch been pushed?")
    files = set(listing.splitlines())
    readme = git(repo, "show", "origin/main:README.md")[1]
    results = []

    def check(label, passed, detail=""):
        results.append(passed)
        print(("PASS  " if passed else "FAIL  ") + label
              + (f"  ({detail})" if detail and not passed else ""))

    f = findings(readme)
    missing = [f"Q{n}" for n in range(1, 6) if n not in f]
    check("README has a ## Findings section with ### Q1 to ### Q5",
          not missing, "missing: " + ", ".join(missing))

    weak = [f"Q{n}" for n, t in sorted(f.items())
            if not has_number(t) or not any(p in files for p in links(t))]
    broken = [f"Q{n}: {p}" for n, t in sorted(f.items()) for p in links(t)
              if p not in files]
    check("every finding states a number and links committed evidence",
          bool(f) and not weak and not broken,
          "; ".join((["no number or no committed link: " + ", ".join(weak)]
                     if weak else []) + broken[:3]))

    wrong = [f"Q{n}" for n, t in sorted(f.items())
             if not set(links(t)) & set(EVIDENCE[n])]
    check("each finding links the evidence for its own question",
          bool(f) and not wrong, ", ".join(wrong))

    q1 = f.get(1, "")
    check("Q1 names the top drug and its count (DUPIXENT, 621)",
          "DUPIXENT" in q1.upper() and re.search(r"\b621\b", q1) is not None)

    q5 = f.get(5, "").lower()
    check("Q5 covers missing values and bulk submissions",
          bool(re.search(r"missing|blank", q5)) and "bulk" in q5)

    ok_tag, tag_commit = git(repo, "rev-parse", "-q", "--verify", "v1.0^{commit}")
    tag_commit = tag_commit.strip()
    on_main = ok_tag and git(repo, "merge-base", "--is-ancestor", tag_commit,
                             "origin/main")[0]
    _, tag_object = git(repo, "rev-parse", "-q", "--verify", "v1.0")
    _, remote = git(repo, "ls-remote", "--tags", "origin", "v1.0")
    pushed = ok_tag and bool(tag_object.strip()) and tag_object.strip() in remote
    tagged_readme = git(repo, "show", "v1.0:README.md")[1] if ok_tag else ""
    has_findings = len(findings(tagged_readme)) == 5
    check("v1.0 is on main, on GitHub, and contains the Findings",
          bool(on_main and pushed and has_findings),
          "tag missing" if not ok_tag else "not on main" if not on_main
          else "not pushed" if not pushed else "v1.0's README lacks the five Findings")

    fresh_ok, why = False, "no tag"
    if ok_tag:
        with tempfile.TemporaryDirectory() as tmp:
            wt = os.path.join(tmp, "v1.0")
            git(repo, "worktree", "add", "-q", "--detach", wt, "v1.0")
            try:
                _, req = run_py(wt, "week04/session_4_2/check_requirements.py")
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
    check("a fresh copy of v1.0: requirements OK, Pipeline OK, Library OK",
          fresh_ok, f"failed at: {why}")
    print(f"\n{sum(results)} of {len(results)} checks passed")


if __name__ == "__main__":
    main()
