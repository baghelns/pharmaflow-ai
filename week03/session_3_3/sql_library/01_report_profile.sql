-- ============================================================
-- PharmaFlow SQL Library · 01_report_profile.sql
-- Question : How big is our sample: reports, dates, drugs, countries, and
--            what share is serious?
-- Asked by : Data Manager (Week 1, Session 2.1)
-- Source   : data/raw/adverse_events_10k.csv
-- Output   : data/processed/library/01_report_profile.parquet (1 row)
-- Checked  : 6,218 reports, 2024-07-01 to 2026-06-04, 104 sampled days, 1,125
--            drugs, 82 countries, 47.0% serious
-- Notes    : The serious share is over the reports with a recorded code (13
--            have none).
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
SELECT COUNT(*) AS reports,
       MIN(report_date) AS first_day,
       MAX(report_date) AS last_day,
       COUNT(DISTINCT report_date) AS sampled_days,
       COUNT(DISTINCT drug_name) AS drugs,
       COUNT(DISTINCT country) AS countries,
       ROUND(100.0 * COUNT(*) FILTER (WHERE serious = '1')
             / COUNT(serious), 1) AS pct_serious
FROM events;

-- Save the answer for other teams.
COPY answer
TO (repo_file('data/processed/library/01_report_profile.parquet'))
    (FORMAT parquet);

-- Show the answer.
SELECT * FROM answer;
