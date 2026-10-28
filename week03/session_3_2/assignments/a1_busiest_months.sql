-- ============================================================
-- Session 3.2 · Assignment 1 (Beginner) · Solution
-- "Which Months Are Busiest Each Year?"
-- Business question: rank the months of each year by reports, keep
-- the three busiest per year (ties included), and check whether the
-- ranking says anything about workload or only about the sample.
-- ============================================================

CREATE OR REPLACE VIEW events AS
SELECT *,
       CAST(strptime(event_date, '%Y%m%d') AS DATE) AS report_date
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

-- Reports and sampled days per month. COUNT(DISTINCT report_date) is
-- the number of different days the sample holds for that month.
CREATE OR REPLACE TABLE monthly AS
SELECT CAST(date_trunc('month', report_date) AS DATE) AS month_start,
       COUNT(*)                    AS reports,
       COUNT(DISTINCT report_date) AS sampled_days
FROM events
GROUP BY month_start;

-- Rank within each year: by reports, and by reports per sampled day.
CREATE OR REPLACE TABLE ranked AS
SELECT year(month_start) AS yr, month_start, reports, sampled_days,
       round(reports * 1.0 / sampled_days, 1) AS per_day,
       RANK() OVER (PARTITION BY year(month_start)
                    ORDER BY reports DESC)    AS rank_reports,
       RANK() OVER (PARTITION BY year(month_start)
                    ORDER BY reports * 1.0 / sampled_days DESC)
                                              AS rank_per_day
FROM monthly;

-- Result 1. The three busiest months of each year, ties included.
SELECT yr, strftime(month_start, '%Y-%m') AS month, reports,
       rank_reports
FROM ranked
WHERE rank_reports <= 3
ORDER BY yr, rank_reports, month_start;

-- Result 2. How much do months differ, and how many days each covers.
SELECT yr, COUNT(*) AS months, MIN(reports) AS fewest,
       MAX(reports) AS most, MIN(sampled_days) AS min_days,
       MAX(sampled_days) AS max_days
FROM ranked
GROUP BY yr
ORDER BY yr;

-- Result 3. The same months ranked by reports per sampled day.
SELECT yr, strftime(month_start, '%Y-%m') AS month, reports,
       sampled_days AS days, per_day, rank_reports AS by_reports,
       rank_per_day AS by_day
FROM ranked
WHERE rank_reports <= 3 OR rank_per_day <= 3
ORDER BY yr, rank_per_day, month_start;
