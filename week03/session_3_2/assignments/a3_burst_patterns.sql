-- ============================================================
-- Session 3.2 · Assignment 3 (Advanced) · Solution
-- "Steady Reporters or Batch Submitters?"
-- Business question: for the ten most-reported drugs, split each
-- drug's reporting days into bursts (a new burst starts after a gap of
-- more than 14 days), count the bursts, and find the share of the
-- drug's reports that arrived in its biggest burst.
-- ============================================================

CREATE OR REPLACE VIEW events AS
SELECT *,
       CAST(strptime(event_date, '%Y%m%d') AS DATE) AS report_date
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

-- Why 14 days: the sample holds about the first week of each month,
-- so two sampled dates more than 14 days apart are in different months.

CREATE OR REPLACE TABLE top10 AS
SELECT drug_name, COUNT(*) AS reports
FROM events
GROUP BY drug_name
ORDER BY reports DESC, drug_name
LIMIT 10;

-- Step 1. One row per drug and reporting day.
CREATE OR REPLACE TABLE drug_days AS
SELECT drug_name, report_date, COUNT(*) AS reports
FROM events
WHERE drug_name IN (SELECT drug_name FROM top10)
GROUP BY drug_name, report_date;

-- Step 2. Flag the first day of each burst (LAG), then number the
-- bursts with a running total of the flags.
CREATE OR REPLACE TABLE burst_days AS
WITH flagged AS (
    SELECT drug_name, report_date, reports,
           CASE WHEN LAG(report_date) OVER w IS NULL
                  OR report_date - LAG(report_date) OVER w > 14
                THEN 1 ELSE 0 END AS starts_burst
    FROM drug_days
    WINDOW w AS (PARTITION BY drug_name ORDER BY report_date)
)
SELECT drug_name, report_date, reports,
       SUM(starts_burst) OVER (PARTITION BY drug_name
                               ORDER BY report_date
                               ROWS BETWEEN UNBOUNDED PRECEDING
                                        AND CURRENT ROW) AS burst_no
FROM flagged;

-- Step 3. One row per burst.
CREATE OR REPLACE TABLE bursts AS
SELECT drug_name, burst_no, MIN(report_date) AS first_day,
       COUNT(*) AS days, SUM(reports) AS reports
FROM burst_days
GROUP BY drug_name, burst_no;

-- Result 1. Checks: every top-10 report sits in exactly one burst.
SELECT (SELECT SUM(reports) FROM top10)  AS top10_reports,
       (SELECT SUM(reports) FROM bursts) AS reports_in_bursts,
       (SELECT COUNT(*) FROM bursts)     AS bursts;

-- Result 2. Per drug: bursts, the biggest burst and its share.
WITH ranked AS (
    SELECT drug_name, burst_no, first_day, reports,
           COUNT(*)     OVER (PARTITION BY drug_name) AS n_bursts,
           SUM(reports) OVER (PARTITION BY drug_name) AS drug_reports,
           ROW_NUMBER() OVER (PARTITION BY drug_name
                              ORDER BY reports DESC, first_day) AS rn
    FROM bursts
)
SELECT drug_name, n_bursts AS bursts, drug_reports AS reports,
       reports AS biggest, first_day AS biggest_starts,
       round(100.0 * reports / drug_reports, 1) AS pct_biggest,
       CASE WHEN 100.0 * reports / drug_reports >= 50 THEN 'batch'
            ELSE 'steady' END AS pattern
FROM ranked
WHERE rn = 1
ORDER BY drug_reports DESC, drug_name;

-- Result 3. The same split with a 31-day rule: how sensitive is it?
WITH flagged AS (
    SELECT drug_name, report_date, reports,
           CASE WHEN LAG(report_date) OVER w IS NULL
                  OR report_date - LAG(report_date) OVER w > 31
                THEN 1 ELSE 0 END AS starts_burst
    FROM drug_days
    WINDOW w AS (PARTITION BY drug_name ORDER BY report_date)
),
numbered AS (
    SELECT drug_name, reports,
           SUM(starts_burst) OVER (PARTITION BY drug_name
                                   ORDER BY report_date
                                   ROWS BETWEEN UNBOUNDED PRECEDING
                                            AND CURRENT ROW) AS burst_no
    FROM flagged
)
SELECT drug_name, COUNT(DISTINCT burst_no) AS bursts_31_days
FROM numbered
GROUP BY drug_name
ORDER BY drug_name;
