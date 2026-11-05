-- ============================================================
-- PharmaFlow SQL Library · 10_monthly_trend.sql
-- Question : Month by month: reports, the running total, and the 3-month
--            moving average of serious reports.
-- Asked by : Data Manager (Session 3.2)
-- Source   : data/raw/adverse_events_10k.csv
-- Output   : data/processed/library/10_monthly_trend.parquet (24 rows)
-- Checked  : 24 months; running total 1,493 at 2024-12 and 6,218 at 2026-06;
--            3-month serious average 125.3 at 2024-09, low 82.7 at 2026-03
-- Notes    : The sample draws about the same number of reports from every
--            month, so the running total is nearly a straight line: it
--            describes the sample, and its last value (6,218) is a
--            completeness check.
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
WITH monthly AS (
    SELECT CAST(date_trunc('month', report_date) AS DATE) AS month_start,
           COUNT(*) AS reports,
           COUNT(*) FILTER (WHERE serious = '1') AS serious_reports
    FROM events
    GROUP BY month_start
)
SELECT month_start,
       reports,
       SUM(reports) OVER (ORDER BY month_start
                          ROWS BETWEEN UNBOUNDED PRECEDING
                                   AND CURRENT ROW) AS running_total,
       serious_reports,
       CASE WHEN COUNT(*) OVER w3 = 3
            THEN ROUND(AVG(serious_reports) OVER w3, 1) END
           AS serious_3m_avg
FROM monthly
WINDOW w3 AS (ORDER BY month_start
              ROWS BETWEEN 2 PRECEDING AND CURRENT ROW);

-- Save the answer for other teams.
COPY answer
TO (repo_file('data/processed/library/10_monthly_trend.parquet'))
    (FORMAT parquet);

-- Show the answer.
SELECT strftime(month_start, '%Y-%m') AS month, reports,
       running_total, serious_reports, serious_3m_avg
FROM answer
ORDER BY month_start;
