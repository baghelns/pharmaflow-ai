# PharmaFlow Foundation: Capstone talk (rewrite)

[Show the README on GitHub]

Medical Affairs asked one thing: which medicines get the most adverse-event
reports, and how far can we trust the answer? PharmaFlow Foundation answers
it from 6,218 real reports in the FDA's openFDA database, July 2024 to June
2026. A Python pipeline pulls the reports, cleans them, stores them as
Parquet and answers five questions in SQL. Anyone can rerun it: three
commands, shown here under How to run it.

[Scroll to Findings]

One. DUPIXENT has the most reports, 621, more than three and a half times
the next drug, CABOMETYX with 170. But six of the top ten drugs, DUPIXENT
included, have days when that one drug made up half or more of all the
reports received. So the ranking partly shows how reports were sent in,
not only how often a drug is reported.

Two. Between 30 and 56 percent of reports are serious in every quarter. The
low point, 2026 Q1 at 30 percent, comes from four single-drug batches. It is
not a safer quarter.

Three. Reactions in the death or hospital care category are serious 92
percent of the time; dosing errors only 4.9 percent. The categories are our
own grouping, not the official MedDRA coding.

Four. The largest drug class, Interleukin-4 receptor antagonists, is almost
entirely DUPIXENT: 621 of its 630 reports. A class ranking can hide a single
drug.

Five. How far can we trust this? Patient age is missing in 48.5 percent of
reports. On 16 of the 104 sampled days, one drug sent half or more of the
day's reports, 894 reports in all. And the sample took about the same
number of reports from every month, so these counts describe the sample,
not how many reports the FDA receives.

[Open queries/08_bulk_submissions.sql]

Every number I gave you comes from a file in this repository, and the
README links each one. This query is how I found the bulk days.

[Show the commit history and the v1.0 tag]

The work went in through pull requests, one change per commit, and v1.0
runs from a fresh copy.

What I would do next: pull a sample that is not limited to a few days a
month, so the counts can be read as trends. Thank you. I'm happy to take
questions.
