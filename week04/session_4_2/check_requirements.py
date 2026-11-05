"""Compare what the code imports with what requirements.txt installs.

Run it from any folder inside a repository:

    python week04/session_4_2/check_requirements.py            # this repo
    python week04/session_4_2/check_requirements.py <folder>   # another repo

It reads every .py file and notebook (.ipynb) that Git tracks, collects the
packages they import, and checks requirements.txt for:
  - packages the code imports that requirements.txt does not install,
  - a package listed more than once,
  - a package with no version pinned (==),
  - a last line with no line ending.
It also lists packages that are installed but never imported: keep those
only if something needs them (openpyxl is used by pandas, jupyter runs
the notebooks).
"""
import ast
import json
import os
import re
import subprocess
import sys

# import name -> name on PyPI, where the two differ
PYPI_NAME = {"sklearn": "scikit-learn", "yaml": "pyyaml", "PIL": "pillow",
             "bs4": "beautifulsoup4", "dateutil": "python-dateutil",
             "mpl_toolkits": "matplotlib"}


def norm(name):
    return re.sub(r"[-_.]+", "-", name).lower()


def committed_files(repo):
    out = subprocess.run(["git", "-C", repo, "ls-files"], capture_output=True,
                         text=True)
    if out.returncode != 0:
        sys.exit(f"{repo} is not a Git repository")
    return out.stdout.splitlines()


def code_of(path):
    """The Python source of a .py file or of a notebook's code cells."""
    if path.endswith(".py"):
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    with open(path, encoding="utf-8") as f:
        nb = json.load(f)
    lines = []
    for cell in nb.get("cells", []):
        if cell.get("cell_type") == "code":
            src = cell.get("source", "")
            src = "".join(src) if isinstance(src, list) else src
            # notebook-only lines such as %matplotlib or !pip are not Python
            lines += [ln for ln in src.splitlines()
                      if not ln.lstrip().startswith(("%", "!"))]
    return "\n".join(lines)


def imports_in(source):
    """Top-level module names imported by this source."""
    try:
        tree = ast.parse(source)
    except SyntaxError:                       # fall back to a line-by-line look
        found = re.findall(r"^\s*(?:from|import)\s+([A-Za-z_]\w*)", source,
                           flags=re.M)
        return set(found)
    names = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            names |= {a.name.split(".")[0] for a in node.names}
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            names.add(node.module.split(".")[0])
    return names


def main():
    start = sys.argv[1] if len(sys.argv) > 1 else "."
    top = subprocess.run(["git", "-C", start, "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True)
    if top.returncode != 0:
        sys.exit(f"{start} is not inside a Git repository")
    repo = top.stdout.strip()
    files = committed_files(repo)
    local = {os.path.splitext(os.path.basename(f))[0] for f in files
             if f.endswith(".py")}
    used = {}                                  # pypi name -> first file using it
    unreadable = []
    for f in files:
        if not f.endswith((".py", ".ipynb")):
            continue
        try:
            names = imports_in(code_of(os.path.join(repo, f)))
        except (OSError, ValueError) as error:
            unreadable.append(f"{f} ({type(error).__name__})")
            continue
        for name in sorted(names):
            if name in sys.stdlib_module_names or name in local:
                continue
            used.setdefault(norm(PYPI_NAME.get(name, name)), f)

    req_path = os.path.join(repo, "requirements.txt")
    if not os.path.exists(req_path):
        sys.exit("No requirements.txt at the repo root")
    with open(req_path, encoding="utf-8") as f:
        raw = f.read()
    listed, problems = {}, []
    for number, line in enumerate(raw.splitlines(), start=1):
        line = line.split("#")[0].strip()
        if not line:
            continue
        name = norm(re.split(r"[<>=!~\[; ]", line, maxsplit=1)[0])
        listed.setdefault(name, []).append((number, line))

    print(f"Tracked code files read: "
          f"{sum(f.endswith(('.py', '.ipynb')) for f in files)}")
    print("Packages imported: " + (", ".join(sorted(used)) or "none"))
    print("Packages in requirements.txt: " + (", ".join(listed) or "none"))
    print()
    for name, first in sorted(used.items()):
        if name not in listed:
            problems.append(f"imported but not in requirements.txt: {name} "
                            f"(first in {first})")
    for name, entries in listed.items():
        if len(entries) > 1:
            lines = " and ".join(str(n) for n, _ in entries)
            problems.append(f"listed more than once: {name} (lines {lines})")
        if not any("==" in text for _, text in entries):
            problems.append(f"no version pinned: {name}")
    if raw and not raw.endswith("\n"):
        problems.append("the last line has no line ending")
    for p in problems:
        print("PROBLEM  " + p)
    for name in listed:
        if name not in used:
            print(f"NOTE     installed but never imported: {name} "
                  "(keep it only if something needs it)")
    for f in unreadable:
        print("NOTE     could not read " + f)
    if problems or unreadable or any(n not in used for n in listed):
        print()
    print("requirements.txt OK" if not problems
          else f"{len(problems)} problem(s) in requirements.txt")


if __name__ == "__main__":
    main()
