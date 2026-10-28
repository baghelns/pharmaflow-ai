-- ============================================================
-- Session 3.2 · Exercise 2 · Intermediate
-- "A Reporting Profile for Every Steady Drug"
-- Business question: for drugs reported in at least 12 of our 24
-- months, when did each first and last appear, which were its two
-- busiest months, and was its busiest month a normal month or a
-- one-off batch?
-- Data: data/raw/adverse_events_10k.csv (6,218 reports)
-- ============================================================

CREATE OR REPLACE VIEW events AS
SELECT *,
       CAST(strptime(event_date, '%Y%m%d') AS DATE) AS report_date
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

-- One row per drug and month that has reports.
CREATE OR REPLACE TABLE drug_months AS
SELECT drug_name,
       CAST(date_trunc('month', report_date) AS DATE) AS month_start,
       COUNT(*) AS reports
FROM events
GROUP BY drug_name, month_start;

-- Every value below is computed over the WHOLE drug, so each window
-- uses the full frame. Two orderings are needed: by month (first,
-- latest) and by size (busiest, second busiest).
CREATE OR REPLACE TABLE profile_rows AS
SELECT drug_name, month_start, reports,
       COUNT(*)     OVER by_drug AS months_reported,
       SUM(reports) OVER by_drug AS total_reports,
       FIRST_VALUE(month_start) OVER by_month AS first_month,
       LAST_VALUE(month_start)  OVER by_month AS latest_month,
       FIRST_VALUE(month_start) OVER by_size  AS busiest_month,
       FIRST_VALUE(reports)     OVER by_size  AS busiest_reports,
       NTH_VALUE(month_start, 2) OVER by_size AS second_month,
       NTH_VALUE(reports, 2)     OVER by_size AS second_reports
FROM drug_months
WINDOW by_drug  AS (PARTITION BY drug_name),
       by_month AS (PARTITION BY drug_name ORDER BY month_start
                    ROWS BETWEEN UNBOUNDED PRECEDING
                             AND UNBOUNDED FOLLOWING),
       by_size  AS (PARTITION BY drug_name
                    ORDER BY reports DESC, month_start
                    ROWS BETWEEN UNBOUNDED PRECEDING
                             AND UNBOUNDED FOLLOWING);

-- One row per drug: every row of a drug carries the same profile,
-- so keep its first month's row.
CREATE OR REPLACE TABLE profile AS
SELECT drug_name, months_reported, total_reports,
       strftime(first_month, '%Y-%m')   AS first_seen,
       strftime(latest_month, '%Y-%m')  AS latest_seen,
       strftime(busiest_month, '%Y-%m') AS busiest,
       busiest_reports,
       strftime(second_month, '%Y-%m')  AS second,
       second_reports,
       round(100.0 * busiest_reports / total_reports, 1) AS peak_pct
FROM profile_rows
WHERE month_start = first_month;

-- Result 1. How many drugs qualify (12+ months)?
SELECT COUNT(*) AS steady_drugs,
       SUM(total_reports) AS their_reports
FROM profile
WHERE months_reported >= 12;

-- Result 2. The ten steadiest drugs: when they were first and
-- latest seen.
SELECT drug_name, months_reported AS months, total_reports AS total,
       first_seen, latest_seen
FROM profile
WHERE months_reported >= 12
ORDER BY months_reported DESC, total_reports DESC, drug_name
LIMIT 10;

-- Result 3. The same ten: their two busiest months, and the share
-- of all their reports that came in the busiest one.
SELECT drug_name, busiest, busiest_reports AS peak,
       second, second_reports AS peak_2, peak_pct
FROM profile
WHERE months_reported >= 12
ORDER BY months_reported DESC, total_reports DESC, drug_name
LIMIT 10;

-- Result 4. Steady drugs whose busiest month holds a quarter or
-- more of all their reports: a one-month batch, not steady growth.
SELECT drug_name, months_reported AS months, total_reports AS total,
       busiest, busiest_reports AS peak, peak_pct
FROM profile
WHERE months_reported >= 12 AND peak_pct >= 25
ORDER BY peak_pct DESC, drug_name;

-- Result 5. The trap, on DUPIXENT: LAST_VALUE with ORDER BY and no
-- frame stops at the current row, so "latest month" changes on
-- every row.
SELECT strftime(month_start, '%Y-%m') AS month, reports,
       strftime(LAST_VALUE(month_start) OVER (
                    PARTITION BY drug_name ORDER BY month_start),
                '%Y-%m') AS latest_default_frame,
       strftime(LAST_VALUE(month_start) OVER (
                    PARTITION BY drug_name ORDER BY month_start
                    ROWS BETWEEN UNBOUNDED PRECEDING
                             AND UNBOUNDED FOLLOWING),
                '%Y-%m') AS latest_full_frame
FROM drug_months
WHERE drug_name = 'DUPIXENT'
ORDER BY month_start
LIMIT 6;
