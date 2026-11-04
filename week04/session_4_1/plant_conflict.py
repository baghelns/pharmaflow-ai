"""Session 4.1 Lab: plant the merge conflict.

Plays the Data Manager, who adds a "Data sources" section to the end of
README.md on GitHub's main while your pull request is open. Your branch
also adds a section to the end of README.md, so the two now conflict and
your pull request on github.com says the branch has conflicts.

Run it once, from any folder inside your pharmaflow-ai repo, after you
have pushed your branch and opened the pull request:

    python week04/session_4_1/plant_conflict.py

It works in a temporary folder that it deletes afterwards: your own
folder, branches and files are not touched. It pushes ONE commit to
GitHub's main. Running it again does nothing.
"""
import os
import subprocess
import sys
import tempfile

MARKER = "## Data sources (added by the Data Manager)"
SECTION = f"""
{MARKER}

- data/raw/openfda_practice_sample.json: 300 real openFDA reports, served
  by the practice API (Session 1.3)
- data/raw/adverse_events_10k.csv: 6,218 usable openFDA reports,
  2024-2026 (Week 2)
"""


def git(*args, cwd=None):
    """Run a git command; return its output, or stop with its error."""
    result = subprocess.run(["git", *args], cwd=cwd,
                            capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"git {' '.join(args)} failed:\n{result.stderr.strip()}")
    return result.stdout.strip()


def main():
    repo = git("rev-parse", "--show-toplevel")
    git("fetch", "-q", "origin", cwd=repo)
    readme_on_github = subprocess.run(
        ["git", "show", "origin/main:README.md"], cwd=repo,
        capture_output=True, text=True).stdout
    if MARKER in readme_on_github:
        print("Already planted: GitHub's main has the Data sources section.")
        return
    with tempfile.TemporaryDirectory() as tmp:
        work = os.path.join(tmp, "main")
        git("worktree", "add", "-q", "--detach", work, "origin/main", cwd=repo)
        try:
            readme = os.path.join(work, "README.md")
            with open(readme, "a", encoding="utf-8") as f:
                f.write(SECTION)
            git("add", "README.md", cwd=work)
            git("-c", "user.name=Data Manager (plant_conflict.py)",
                "-c", "user.email=data.manager@pharmaflow.example",
                "commit", "-q", "-m", "README: list the data sources",
                cwd=work)
            git("push", "-q", "origin", "HEAD:main", cwd=work)
        finally:
            git("worktree", "remove", "--force", work, cwd=repo)
    print("Planted: the Data Manager pushed \"README: list the data "
          "sources\" to GitHub's main.")
    print("Your pull request now has a conflict in README.md.")


if __name__ == "__main__":
    main()
