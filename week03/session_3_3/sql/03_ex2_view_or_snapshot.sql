-- ============================================================
-- Session 3.3 · Exercise 2 · Intermediate
-- "A Live View or a Frozen Snapshot?"
-- Business question: Medical Affairs presents the Q1 2026 figures
-- and needs them to stay fixed, while the monitoring screen must
-- show every new delivery. Which one is a VIEW and which a TABLE
-- made with CREATE TABLE AS (CTAS)? Prove the difference.
-- Data: data/raw/adverse_events_10k.csv (6,218 reports); this file
-- writes data/processed/delivery_2026.csv twice
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

-- Delivery 1: the reports of January to March 2026, written as a
-- CSV with the original eight columns (EXCLUDE drops report_date).
COPY (SELECT * EXCLUDE (report_date)
      FROM events
      WHERE report_date BETWEEN DATE '2026-01-01' AND DATE '2026-03-31'
      ORDER BY safety_report_id)
TO (repo_file('data/processed/delivery_2026.csv'));

-- The live view: only a saved query. It reads the file again every
-- time it is used.
CREATE OR REPLACE VIEW live_2026 AS
SELECT *,
       CAST(strptime(event_date, '%Y%m%d') AS DATE) AS report_date
FROM read_csv('data/processed/delivery_2026.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

-- The snapshot: CTAS runs the query once and stores the rows.
CREATE OR REPLACE TABLE snapshot_q1 AS
SELECT * FROM live_2026;

-- Result 1. Straight after delivery 1, both give the same count.
SELECT (SELECT COUNT(*) FROM live_2026)   AS view_reports,
       (SELECT COUNT(*) FROM snapshot_q1) AS table_reports;

-- Delivery 2 replaces the file: January to June 2026.
COPY (SELECT * EXCLUDE (report_date)
      FROM events
      WHERE report_date BETWEEN DATE '2026-01-01' AND DATE '2026-06-30'
      ORDER BY safety_report_id)
TO (repo_file('data/processed/delivery_2026.csv'));

-- Result 2. The view has read the new file; the table has not.
SELECT (SELECT COUNT(*) FROM live_2026)   AS view_reports,
       (SELECT COUNT(*) FROM snapshot_q1) AS table_reports;

-- Result 3. Month by month: April to June exist only in the view.
-- A FULL JOIN keeps months that only one side has.
WITH v AS (
    SELECT CAST(date_trunc('month', report_date) AS DATE) AS month_start,
           COUNT(*) AS view_reports
    FROM live_2026
    GROUP BY month_start
), t AS (
    SELECT CAST(date_trunc('month', report_date) AS DATE) AS month_start,
           COUNT(*) AS table_reports
    FROM snapshot_q1
    GROUP BY month_start
)
SELECT strftime(month_start, '%Y-%m') AS month,
       v.view_reports,
       COALESCE(t.table_reports, 0) AS table_reports
FROM v
FULL JOIN t USING (month_start)
ORDER BY month_start;

-- Result 4. Which objects DuckDB holds now, and what each one is.
-- duckdb_tables() and duckdb_views() list them; internal = false
-- leaves out DuckDB's own system views.
SELECT table_name AS name, 'table' AS kind,
       estimated_size AS rows_stored
FROM duckdb_tables()
UNION ALL
SELECT view_name, 'view', NULL
FROM duckdb_views()
WHERE NOT internal
ORDER BY kind, name;
