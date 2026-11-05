"""Exercise 5 (Interview Challenge) solution: check_readme_links(repo).

Every relative link and image in README.md must point to a file (or
folder) that is committed in the repository. Links to websites
(http://, https://, mailto:) and links to a heading in the same file
(#...) are not checked. Links inside code blocks are ignored.
Constraints: never raise, whatever `repo` is; a repo with no README or
no commits is reported, not crashed on.
Run: python check_readme_links.py <repo folder> [<repo folder> ...]
"""
import os
import re
import subprocess
import sys

# [text](target) and ![alt](target "optional title")
LINK = re.compile(r"!?\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")


def git(repo, *args):
    """Run git in `repo`; return (ok, output). Never raises."""
    try:
        r = subprocess.run(["git", "-C", repo, *args],
                           capture_output=True, text=True)
    except (OSError, ValueError):
        return False, ""
    return r.returncode == 0, r.stdout


def check_readme_links(repo):
    """Return a list of problems with README.md's links; [] means OK."""
    if not os.path.isdir(repo):
        return [f"{repo}: no such folder"]
    ok, top = git(repo, "rev-parse", "--show-toplevel")
    if not ok:
        return [f"{repo}: not a Git repository"]
    top = top.strip()
    ok, listing = git(top, "ls-tree", "-r", "--name-only", "--full-tree",
                      "HEAD")
    committed = set(listing.splitlines())
    folders = {os.path.dirname(f) for f in committed}
    folders |= {p for f in folders for p in _parents(f)}
    if "README.md" not in committed:
        return ["README.md is not committed"]
    try:
        with open(os.path.join(top, "README.md"), encoding="utf-8") as f:
            text = f.read()
    except (OSError, UnicodeDecodeError) as error:
        return [f"README.md cannot be read ({type(error).__name__})"]
    problems = []
    in_code = False
    for number, line in enumerate(text.splitlines(), start=1):
        if line.lstrip().startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            continue
        for target in LINK.findall(line):
            if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or \
                    target.startswith("#"):
                continue                       # website, e-mail, same-page
            path = os.path.normpath(target.split("#")[0].split("?")[0])
            path = path.lstrip("/") if target.startswith("/") else path
            if path.startswith(".."):
                problems.append(f"line {number}: {target} points outside "
                                "the repository")
            elif path not in committed and path not in folders:
                problems.append(f"line {number}: {target} is not a "
                                "committed file")
    return problems


def _parents(folder):
    while folder:
        folder = os.path.dirname(folder)
        if folder:
            yield folder


if __name__ == "__main__":
    for folder in sys.argv[1:]:
        found = check_readme_links(folder)
        print(f"{folder}: " + ("all README links OK" if not found
                               else f"{len(found)} problem(s)"))
        for p in found:
            print("  " + p)
