-- ============================================================
-- PharmaFlow SQL Library · 09_rank_in_class.sql
-- Question : How does each drug rank by reports within its own drug class?
-- Asked by : Medical Affairs (Session 3.2)
-- Source   : data/raw/adverse_events_10k.csv + data/raw/drug_reference.csv
--            (join on drug_name)
-- Output   : data/processed/library/09_rank_in_class.parquet (521 rows, one
--            per classified drug; the preview shows the leaders of the 8
--            largest classes)
-- Checked  : 521 drugs; leaders DUPIXENT 621 of 630, SKYRIZI 139 of 171,
--            RINVOQ 105 of 127
-- Notes    : RANK: tied drugs share a rank. A drug with no class cannot be
--            ranked within one.
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

CREATE OR REPLACE VIEW drug_ref AS
SELECT * FROM read_csv('data/raw/drug_reference.csv');

CREATE OR REPLACE TABLE answer AS
WITH drug_counts AS (
    SELECT r.drug_class, e.drug_name, COUNT(*) AS reports
    FROM events AS e
    INNER JOIN drug_ref AS r ON e.drug_name = r.drug_name
    GROUP BY r.drug_class, e.drug_name
)
SELECT drug_class, drug_name, reports,
       RANK() OVER (PARTITION BY drug_class
                    ORDER BY reports DESC) AS rank_in_class,
       SUM(reports) OVER (PARTITION BY drug_class) AS class_reports
FROM drug_counts;

-- Save the answer for other teams.
COPY answer
TO (repo_file('data/processed/library/09_rank_in_class.parquet'))
    (FORMAT parquet);

-- Show the answer.
SELECT CASE WHEN length(drug_class) > 30
            THEN left(drug_class, 29) || '…' ELSE drug_class END
           AS class_label,
       drug_name, reports, class_reports
FROM answer
WHERE rank_in_class = 1
ORDER BY class_reports DESC, drug_class, drug_name
LIMIT 8;
