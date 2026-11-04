"""Session 4.1 Lab checker. Run it from any folder inside your pharmaflow-ai
repo when you think the Lab is finished:

    python week04/session_4_1/check_lab_4_1.py

It prints PASS or FAIL for each of eight checks and a total. It changes
nothing in your repository: the last check runs the pipeline from a fresh
copy of your v0.1 tag in a temporary folder, deleted afterwards.
"""
import os
import subprocess
import sys
import tempfile

BRANCH = "feature/foundation-pipeline"
SCRIPTS = ["scripts/ingest.py", "scripts/clean.py",
           "scripts/store_and_query.py"]
DATA_MANAGER = "## Data sources (added by the Data Manager)"
YOUR_SECTION = "## Run the PharmaFlow Foundation pipeline"


def git(*args, cwd):
    """Run git; return (ok, output)."""
    r = subprocess.run(["git", *args], cwd=cwd, capture_output=True,
                       text=True)
    return r.returncode == 0, r.stdout.strip()


def branch_ref(repo):
    """The branch on GitHub, or the local one if it was deleted there."""
    for ref in (f"origin/{BRANCH}", BRANCH):
        if git("rev-parse", "--verify", "-q", ref, cwd=repo)[0]:
            return ref
    return None


def three_commits(repo, ref):
    """Each script arrives in a commit of its own (that commit changes no
    other file), in pipeline order. Later fixes to a script are fine."""
    _, out = git("log", "--reverse", "--format=%H", ref, cwd=repo)
    arrived = []
    for sha in out.split():
        _, files = git("show", "--format=", "--name-only", sha, cwd=repo)
        files = files.split()
        if len(files) == 1 and files[0] in SCRIPTS:
            if files[0] not in arrived:
                arrived.append(files[0])
        elif any(f in SCRIPTS and f not in arrived for f in files):
            return False          # a script arrived together with other files
    return arrived == SCRIPTS


def merged_by_merge_commit(repo, ref):
    """main has a merge commit whose second parent brings the scripts."""
    _, merges = git("log", "main", "--merges", "--format=%H", cwd=repo)
    for sha in merges.split():
        ok, _ = git("cat-file", "-e", f"{sha}^2:scripts/store_and_query.py",
                    cwd=repo)
        if ok:
            return True
    return False


def readme_has_both(repo):
    ok, text = git("show", "main:README.md", cwd=repo)
    return ok and DATA_MANAGER in text and YOUR_SECTION in text


def no_markers(repo):
    ok, out = git("grep", "-n", "-E", "^(<<<<<<<|>>>>>>>) ", "main",
                  cwd=repo)
    return not ok and out == ""


def tag_on_main(repo):
    ok, _ = git("merge-base", "--is-ancestor", "v0.1^{commit}", "main",
                cwd=repo)
    has = all(git("cat-file", "-e", f"v0.1^{{commit}}:{s}", cwd=repo)[0]
              for s in SCRIPTS)
    return ok and has


def tag_on_github(repo):
    ok, out = git("ls-remote", "--tags", "origin", "v0.1", cwd=repo)
    return ok and "refs/tags/v0.1" in out


def main_pushed(repo):
    a = git("rev-parse", "main", cwd=repo)[1]
    b = git("rev-parse", "origin/main", cwd=repo)[1]
    return a != "" and a == b


def tagged_pipeline_runs(repo):
    """Run the three scripts from a fresh copy of v0.1."""
    with tempfile.TemporaryDirectory() as tmp:
        work = os.path.join(tmp, "v0.1")
        if not git("worktree", "add", "-q", "--detach", work, "v0.1",
                   cwd=repo)[0]:
            return False
        try:
            last = ""
            for script in SCRIPTS:
                r = subprocess.run([sys.executable, script], cwd=work,
                                   capture_output=True, text=True)
                last = r.stdout
                if r.returncode != 0:
                    print("      " + (r.stderr.strip().splitlines() or
                                      ["(no message)"])[-1][:70])
                    return False
            return "Pipeline OK" in last
        finally:
            git("worktree", "remove", "--force", work, cwd=repo)


def main():
    ok, repo = git("rev-parse", "--show-toplevel", cwd=os.getcwd())
    if not ok:
        sys.exit("Run this from inside your pharmaflow-ai repo.")
    git("fetch", "-q", "origin", "--tags", cwd=repo)
    ref = branch_ref(repo)
    has_tag = git("rev-parse", "--verify", "-q", "v0.1", cwd=repo)[0]
    checks = [
        (f"branch {BRANCH} exists", lambda: ref is not None),
        ("three commits on it, one per script, in pipeline order",
         lambda: ref is not None and three_commits(repo, ref)),
        ("main merged the branch with a merge commit (the pull request)",
         lambda: ref is not None and merged_by_merge_commit(repo, ref)),
        ("README.md on main keeps both sections (conflict resolved)",
         lambda: readme_has_both(repo)),
        ("no conflict markers left in any file on main",
         lambda: no_markers(repo)),
        ("tag v0.1 is on main and contains the three scripts",
         lambda: has_tag and tag_on_main(repo)),
        ("tag v0.1 is on GitHub and main is pushed",
         lambda: tag_on_github(repo) and main_pushed(repo)),
        ("a fresh copy of v0.1 runs the pipeline: Pipeline OK",
         lambda: has_tag and tagged_pipeline_runs(repo)),
    ]
    passed = 0
    for text, test in checks:
        result = bool(test())
        passed += result
        print(("PASS  " if result else "FAIL  ") + text)
    print(f"{passed} of {len(checks)} checks passed")


if __name__ == "__main__":
    main()
