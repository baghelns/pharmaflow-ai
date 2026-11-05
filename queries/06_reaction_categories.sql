-- ============================================================
-- PharmaFlow SQL Library · 06_reaction_categories.sql
-- Question : Which kinds of reaction are reported most, and how often are
--            they serious?
-- Asked by : Pharmacovigilance Lead (Session 2.2)
-- Source   : data/raw/adverse_events_10k.csv +
--            data/raw/reaction_categories.csv (join on reaction)
-- Output   : data/processed/library/06_reaction_categories.parquet (12 rows:
--            11 categories and Unmapped)
-- Checked  : Unmapped 1,935 (63.3% serious); Product use or dosing error 793
--            (4.9%); Death or hospital care 410 (92.0%)
-- Notes    : reaction_categories.csv is built for this course, not an
--            official coding (not MedDRA). It covers reactions with 5+
--            reports; the rest are Unmapped.
-- ============================================================

-- COPY writes relative to the folder you run from; repo_file()
-- builds the path from the repo root (Session 3.3).
CREATE OR REPLACE MACRO repo_file(p) AS
    current_setting('file_search_path') || '/' || p;

CREATE OR REPLACE VIEW events AS
SELECT *,
       CAST(strptime(event_date, '%Y%m%d') AS DATE) AS report_date
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

CREATE OR REPLACE VIEW reaction_map AS
SELECT * FROM read_csv('data/raw/reaction_categories.csv');

CREATE OR REPLACE TABLE answer AS
SELECT COALESCE(m.reaction_category, 'Unmapped') AS reaction_category,
       COUNT(*) AS reports,
       ROUND(100.0 * COUNT(*) FILTER (WHERE e.serious = '1')
             / COUNT(e.serious), 1) AS pct_serious
FROM events AS e
LEFT JOIN reaction_map AS m ON e.reaction = m.reaction
GROUP BY ALL;

-- Save the answer for other teams.
COPY answer
TO (repo_file('data/processed/library/06_reaction_categories.parquet'))
    (FORMAT parquet);

-- Show the answer.
SELECT * FROM answer ORDER BY reports DESC, reaction_category;
