-- ============================================================
-- PharmaFlow SQL Library · 03_top10_drugs.sql
-- Question : Which ten drugs have the most reports, and how serious are they?
-- Asked by : Data Manager (Week 1, Session 3.1)
-- Source   : data/raw/adverse_events_10k.csv
-- Output   : data/processed/library/03_top10_drugs.parquet (10 rows)
-- Checked  : DUPIXENT 621 (8.4% serious), CABOMETYX 170, SKYRIZI 139, RINVOQ
--            105, RYALTRIS 79; tenth VICTOZA 69
-- Notes    : Several of the ten are there because of one bulk submission (see
--            08).
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
SELECT drug_name,
       COUNT(*) AS reports,
       ROUND(100.0 * COUNT(*) FILTER (WHERE serious = '1')
             / COUNT(serious), 1) AS pct_serious
FROM events
GROUP BY drug_name
ORDER BY reports DESC, drug_name
LIMIT 10;

-- Save the answer for other teams.
COPY answer
TO (repo_file('data/processed/library/03_top10_drugs.parquet'))
    (FORMAT parquet);

-- Show the answer.
SELECT * FROM answer ORDER BY reports DESC, drug_name;
