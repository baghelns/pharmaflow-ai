-- ============================================================
-- Session 3.2 · Exercise 4 · Corporate Scenario
-- "The Dashboard Says Serious Reports Hit a Record Low"
-- Business question: the safety dashboard's 3-month rolling serious
-- share fell to 30.0% in March 2026, its lowest. Is that real, or
-- is it the bulk submissions we found in Week 2?
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

-- Step 1. Find the bulk submissions with a window: each drug's share
-- of its day's reports. SUM(...) OVER (PARTITION BY event_date) is
-- the day's total, written on every row of that day.
CREATE OR REPLACE TABLE drug_days AS
SELECT event_date, drug_name, COUNT(*) AS reports
FROM events
GROUP BY event_date, drug_name;

-- A window function cannot go in WHERE (WHERE runs first), so the
-- share is worked out in a CTE and filtered afterwards. A batch: one
-- drug with half or more of its day's reports, and at least 20.
CREATE OR REPLACE TABLE batches AS
WITH shares AS (
    SELECT event_date, drug_name, reports,
           reports * 1.0 / SUM(reports) OVER (PARTITION BY event_date)
                                                   AS share_of_day
    FROM drug_days
)
SELECT event_date, drug_name, reports, share_of_day
FROM shares
WHERE share_of_day >= 0.5 AND reports >= 20;

-- Step 2. Monthly counts, with and without the batch reports.
-- The serious share's denominator is the reports whose seriousness
-- is recorded: COUNT(serious) skips the 13 NULLs.
CREATE OR REPLACE TABLE monthly AS
SELECT CAST(date_trunc('month', e.report_date) AS DATE) AS month_start,
       COUNT(*) FILTER (WHERE e.serious = '1')          AS serious,
       COUNT(e.serious)                                  AS recorded,
       COUNT(b.drug_name)                                AS batch_reports,
       COUNT(*) FILTER (WHERE e.serious = '1'
                          AND b.drug_name IS NULL)       AS serious_nb,
       COUNT(e.serious) FILTER (WHERE b.drug_name IS NULL)
                                                         AS recorded_nb
FROM events AS e
LEFT JOIN batches AS b
       ON b.event_date = e.event_date AND b.drug_name = e.drug_name
GROUP BY month_start;

-- Step 3. The rolling share: total serious / total recorded over the
-- 3-month frame (not the average of three monthly shares). NULL until
-- three months exist, so no "3-month" figure is really 1 or 2 months.
CREATE OR REPLACE TABLE rolling AS
SELECT month_start, serious, recorded, batch_reports,
       COUNT(*) OVER w3 AS months_in_frame,
       CASE WHEN COUNT(*) OVER w3 = 3
            THEN round(100.0 * SUM(serious) OVER w3
                             / SUM(recorded) OVER w3, 1) END
                                                  AS rolling_share,
       CASE WHEN COUNT(*) OVER w3 = 3
            THEN round(100.0 * SUM(serious_nb) OVER w3
                             / SUM(recorded_nb) OVER w3, 1) END
                                                  AS rolling_no_batch
FROM monthly
WINDOW w3 AS (ORDER BY month_start
              ROWS BETWEEN 2 PRECEDING AND CURRENT ROW);

-- Result 1. The bulk submissions the window found.
SELECT COUNT(*) AS batch_days, SUM(reports) AS batch_reports,
       COUNT(DISTINCT drug_name) AS drugs
FROM batches;

-- Result 2. The largest five, with the drug's share of its day.
SELECT event_date, drug_name, reports,
       round(100.0 * share_of_day, 1) AS pct_of_day
FROM batches
ORDER BY reports DESC, event_date
LIMIT 5;

-- Result 3. The dashboard line, month by month, with and without
-- the batches.
-- (roll_pct = with batches, roll_nb = without them)
SELECT strftime(month_start, '%Y-%m') AS month, serious,
       recorded AS rec, batch_reports AS batch,
       months_in_frame AS frame, rolling_share AS roll_pct,
       rolling_no_batch AS roll_nb
FROM rolling
ORDER BY month_start;

-- Result 4. The three lowest rolling months, each way.
SELECT 'with batches' AS version, strftime(month_start, '%Y-%m')
           AS month, rolling_share AS share
FROM (SELECT * FROM rolling WHERE rolling_share IS NOT NULL
      ORDER BY rolling_share, month_start LIMIT 3)
UNION ALL
SELECT 'without batches', strftime(month_start, '%Y-%m'),
       rolling_no_batch
FROM (SELECT * FROM rolling WHERE rolling_no_batch IS NOT NULL
      ORDER BY rolling_no_batch, month_start LIMIT 3)
ORDER BY version DESC, share, month;
