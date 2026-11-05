-- ============================================================
-- PharmaFlow SQL Library · 08_bulk_submissions.sql
-- Question : On which days did one drug send half or more of the day's
--            reports (a bulk submission)?
-- Asked by : Pharmacovigilance Lead (Weeks 2 and 3)
-- Source   : data/raw/adverse_events_10k.csv
-- Output   : data/processed/library/08_bulk_submissions.parquet (16 rows)
-- Checked  : 16 days, 894 reports; largest RYALTRIS 2025-02-01, 79 reports
--            (94.0% of the day)
-- Notes    : Rule from Week 2: one drug, at least 50% of its day's reports
--            and at least 20 of them.
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

CREATE OR REPLACE TABLE answer AS
WITH drug_days AS (
    SELECT report_date, drug_name, COUNT(*) AS reports
    FROM events
    GROUP BY report_date, drug_name
), shares AS (
    SELECT report_date, drug_name, reports,
           ROUND(100.0 * reports
                 / SUM(reports) OVER (PARTITION BY report_date), 1)
               AS pct_of_day
    FROM drug_days
)
SELECT report_date, drug_name, reports, pct_of_day
FROM shares
WHERE pct_of_day >= 50 AND reports >= 20;

-- Save the answer for other teams.
COPY answer
TO (repo_file('data/processed/library/08_bulk_submissions.parquet'))
    (FORMAT parquet);

-- Show the answer.
SELECT * FROM answer ORDER BY reports DESC, report_date, drug_name;
