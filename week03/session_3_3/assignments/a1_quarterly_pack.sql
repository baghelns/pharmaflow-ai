-- ============================================================
-- Session 3.3 · Assignment 1 (Beginner) · Solution
-- "A Quarterly Delivery Pack for Regulatory Affairs"
-- Business question: deliver the reports as one Parquet file per
-- quarter, with a manifest that proves every quarter is there and
-- nothing was lost on the way.
-- ============================================================

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

-- One label per quarter, such as 2024Q3: it becomes the folder name.
CREATE OR REPLACE TABLE pack AS
SELECT *,
       strftime(report_date, '%Y') || 'Q' || quarter(report_date) AS qtr
FROM events
ORDER BY report_date, safety_report_id;

-- One folder per quarter: data/processed/quarterly/qtr=2024Q3/...
COPY pack TO (repo_file('data/processed/quarterly'))
    (FORMAT parquet, PARTITION_BY (qtr), OVERWRITE);

-- Result 1. The manifest, read back from the files themselves:
-- one row per quarter with its file, reports and first and last day.
SELECT qtr,
       COUNT(DISTINCT filename) AS files,
       COUNT(*) AS reports,
       MIN(report_date) AS first_day,
       MAX(report_date) AS last_day
FROM read_parquet('data/processed/quarterly/*/*.parquet',
                  hive_partitioning = true, filename = true)
GROUP BY qtr
ORDER BY qtr;

-- Result 2. The check: the files hold exactly the source's reports,
-- each once.
SELECT (SELECT COUNT(*) FROM events) AS source_reports,
       COUNT(*) AS reports_in_files,
       COUNT(DISTINCT safety_report_id) AS distinct_ids,
       COUNT(DISTINCT qtr) AS quarters
FROM read_parquet('data/processed/quarterly/*/*.parquet',
                  hive_partitioning = true);

-- Result 3. The types the recipients will get, with no options.
SELECT column_name, column_type
FROM (DESCRIBE SELECT *
      FROM read_parquet('data/processed/quarterly/*/*.parquet'))
WHERE column_name IN ('safety_report_id', 'serious', 'event_date',
                      'report_date', 'qtr');
