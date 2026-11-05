-- ============================================================
-- PharmaFlow SQL Library · 02_missing_values.sql
-- Question : How many reports leave each column blank?
-- Asked by : Data Manager (Session 2.1)
-- Source   : data/raw/adverse_events_10k.csv
-- Output   : data/processed/library/02_missing_values.parquet (8 rows, one
--            per column)
-- Checked  : patient_age and patient_age_unit 3,016 blank (48.5%), country
--            403 (6.5%), serious 13 (0.2%), the rest 0
-- Notes    : A blank country is a real gap in the data, not the code NA.
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
SELECT column_name,
       blanks,
       ROUND(100.0 * blanks / (SELECT COUNT(*) FROM events), 1)
           AS pct_blank
FROM (
    -- UNPIVOT turns the one wide row of counts into one row per column
    UNPIVOT (
        SELECT COUNT(*) - COUNT(safety_report_id) AS safety_report_id,
               COUNT(*) - COUNT(drug_name)        AS drug_name,
               COUNT(*) - COUNT(reaction)         AS reaction,
               COUNT(*) - COUNT(serious)          AS serious,
               COUNT(*) - COUNT(patient_age)      AS patient_age,
               COUNT(*) - COUNT(patient_age_unit) AS patient_age_unit,
               COUNT(*) - COUNT(country)          AS country,
               COUNT(*) - COUNT(event_date)       AS event_date
        FROM events
    ) ON COLUMNS(*) INTO NAME column_name VALUE blanks
)
ORDER BY blanks DESC, column_name;

-- Save the answer for other teams.
COPY answer
TO (repo_file('data/processed/library/02_missing_values.parquet'))
    (FORMAT parquet);

-- Show the answer.
SELECT * FROM answer ORDER BY blanks DESC, column_name;
