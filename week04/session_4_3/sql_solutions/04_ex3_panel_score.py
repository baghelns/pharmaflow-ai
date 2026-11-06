"""Exercise 3: score like the panel.
Part A: what the Capstone checker's Findings rules say about a Findings
section written in a hurry. Part B: the badge decision from two panellists'
scores (PROPOSED rule: the average of the two totals, rounded down; 16 or
more earns the badge; totals more than 3 apart are talked through first).
Run from the repo root: python 04_ex3_panel_score.py <weak_findings.md>"""
import math
import os
import subprocess
import sys

ROOT = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                      capture_output=True, text=True).stdout.strip()
sys.path.insert(0, os.path.join(ROOT, "week04", "session_4_3"))
from check_capstone_4_3 import EVIDENCE, findings, has_number, links  # noqa: E402

CATEGORIES = ["code quality", "documentation", "data findings",
              "repo structure"]


def describe(path):
    text = "## Findings\n" + open(path, encoding="utf-8").read().split(
        "## Findings", 1)[-1]
    committed = set(subprocess.run(["git", "-C", ROOT, "ls-files"],
                                   capture_output=True,
                                   text=True).stdout.split())
    found = findings(text)
    for n in range(1, 6):
        if n not in found:
            print(f"Q{n}: missing")
            continue
        t, ls = found[n], links(found[n])
        print(f"Q{n}: number {'yes' if has_number(t) else 'NO'};"
              f" committed link {'yes' if any(p in committed for p in ls) else 'NO'};"
              f" its own evidence {'yes' if set(ls) & set(EVIDENCE[n]) else 'NO'}")


def badge(instructor, peer):
    for scores in (instructor, peer):
        if len(scores) != 4 or any(s not in range(6) for s in scores):
            raise ValueError("four scores from 0 to 5, one per category")
    a, b = sum(instructor), sum(peer)
    final = math.floor((a + b) / 2)
    note = "talk it through first; " if abs(a - b) > 3 else ""
    return (f"instructor {a}, peer {b} -> {final}/20: {note}"
            + ("Foundation Badge" if final >= 16 else "no badge yet"))


if __name__ == "__main__":
    describe(sys.argv[1])
    print()
    for i, p in [([4, 4, 3, 4], [5, 4, 4, 4]), ([4, 4, 4, 3], [4, 4, 4, 4]),
                 ([5, 5, 5, 5], [3, 3, 3, 3]), ([4, 4, 4, 4], [4, 4, 4, 4])]:
        print(badge(i, p))
    try:
        badge([4, 4, 4, 6], [4, 4, 4, 4])
    except ValueError as e:
        print("ValueError:", e)
