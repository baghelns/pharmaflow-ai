-- ============================================================
-- PharmaFlow SQL Library · 05_drug_classes.sql
-- Question : Which drug classes have more than 100 reports?
-- Asked by : Medical Affairs (Sessions 2.2 and 3.1)
-- Source   : data/raw/adverse_events_10k.csv + data/raw/drug_reference.csv
--            (join on drug_name)
-- Output   : data/processed/library/05_drug_classes.parquet (8 rows)
-- Checked  : 8 classes; Interleukin-4 630 reports, Interleukin-23 171,
--            Thalidomide Analog 161; smallest GLP-1 113
-- Notes    : Threshold 100, not the curriculum's 1000: the largest class has
--            630 reports. 2,231 reports have no class and are not counted.
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
SELECT r.drug_class,
       COUNT(*) AS reports,
       COUNT(DISTINCT e.drug_name) AS drugs,
       ROUND(100.0 * COUNT(*) FILTER (WHERE e.serious = '1')
             / COUNT(e.serious), 1) AS pct_serious
FROM events AS e
INNER JOIN drug_ref AS r ON e.drug_name = r.drug_name
GROUP BY r.drug_class
HAVING COUNT(*) > 100;

-- Save the answer for other teams.
COPY answer
TO (repo_file('data/processed/library/05_drug_classes.parquet'))
    (FORMAT parquet);

-- Show the answer.
SELECT CASE WHEN length(drug_class) > 30
            THEN left(drug_class, 29) || '…' ELSE drug_class END
           AS class_label,
       reports, drugs, pct_serious
FROM answer
ORDER BY reports DESC, drug_class;
