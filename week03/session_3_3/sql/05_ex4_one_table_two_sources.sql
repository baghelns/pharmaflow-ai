-- ============================================================
-- Session 3.3 · Exercise 4 · Corporate Scenario
-- "One Table for Every Report We Have Pulled"
-- Business question: the Pharmacovigilance Lead wants Week 1's JSON
-- reports and Week 2's CSV reports in one table, saved as Parquet
-- with one folder per source, and asks: "Is the serious share going
-- down over the years?"
-- Data: data/raw/adverse_events_10k.csv (6,218 reports)
--       data/raw/adverse_events_1000.json (1,000 reports)
-- Writes data/processed/all_reports/ (one folder per source)
-- ============================================================

CREATE OR REPLACE MACRO repo_file(p) AS
    current_setting('file_search_path') || '/' || p;

-- Both sources with the same columns and types, and a column that
-- says where each row came from. The JSON has no patient_age_unit,
-- and its patient_age is text: TRY_CAST turns it into a number
-- (and would give NULL, not an error, for text such as 'unknown').
CREATE OR REPLACE TABLE all_reports AS
SELECT 'csv_10k_2024_2026' AS source,
       safety_report_id, drug_name, reaction, serious,
       CAST(patient_age AS INTEGER) AS patient_age,
       patient_age_unit, country,
       CAST(strptime(event_date, '%Y%m%d') AS DATE) AS report_date
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'})
UNION ALL BY NAME
SELECT 'json_1000_2014' AS source,
       safety_report_id, drug_name, reaction, serious,
       TRY_CAST(patient_age AS INTEGER) AS patient_age,
       country,
       CAST(strptime(event_date, '%Y%m%d') AS DATE) AS report_date
FROM read_json('data/raw/adverse_events_1000.json');

-- Result 1. Rows per source, and the check: both sources add up to
-- the combined table, with no report ID twice.
SELECT source, COUNT(*) AS reports,
       COUNT(DISTINCT safety_report_id) AS ids,
       MIN(report_date) AS first_day, MAX(report_date) AS last_day
FROM all_reports
GROUP BY source
UNION ALL
SELECT 'TOTAL', COUNT(*), COUNT(DISTINCT safety_report_id),
       MIN(report_date), MAX(report_date)
FROM all_reports
ORDER BY source = 'TOTAL', source;  -- TOTAL last

-- Result 2. The question as asked: the serious share by year.
-- Read the source column before you read the trend.
SELECT year(report_date) AS report_year,
       source,
       COUNT(*) AS reports,
       ROUND(100.0 * COUNT(*) FILTER (WHERE serious = '1')
             / COUNT(serious), 1) AS pct_serious
FROM all_reports
GROUP BY report_year, source
ORDER BY report_year, source;

-- Result 3. What the combined table cannot tell you: the JSON rows
-- have an age but no unit, so "45" may mean years, months or
-- decades. Count each case per source.
SELECT source,
       COUNT(*) FILTER (WHERE patient_age IS NOT NULL
                          AND patient_age_unit IS NOT NULL)
           AS age_with_unit,
       COUNT(*) FILTER (WHERE patient_age IS NOT NULL
                          AND patient_age_unit IS NULL)
           AS age_without_unit,
       COUNT(*) FILTER (WHERE patient_age IS NULL) AS no_age
FROM all_reports
GROUP BY source
ORDER BY source;

-- Save the table as Parquet, one folder per source. PARTITION_BY
-- writes data/processed/all_reports/source=<value>/ folders;
-- OVERWRITE replaces what an earlier run wrote there.
COPY all_reports TO (repo_file('data/processed/all_reports'))
    (FORMAT parquet, PARTITION_BY (source), OVERWRITE);

-- Result 4. Read every file in the folder back with one pattern:
-- the first * matches each source= folder, the second each file.
-- hive_partitioning turns the folder name source=... back into a
-- column (DuckDB does this by default; writing it makes it clear).
-- The counts must match Result 1.
SELECT source,
       COUNT(*) AS reports,
       COUNT(DISTINCT filename) AS files
FROM read_parquet('data/processed/all_reports/*/*.parquet',
                  hive_partitioning = true, filename = true)
GROUP BY source
ORDER BY source;
