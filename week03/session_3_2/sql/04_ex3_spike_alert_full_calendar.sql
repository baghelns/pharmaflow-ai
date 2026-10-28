-- ============================================================
-- Session 3.2 · Exercise 3 · Advanced
-- "The +8,400% Alert: LAG Needs Every Quarter"
-- Business question: for the eight most-reported drugs, which
-- quarters more than doubled their reports on the quarter before?
-- A first draft flagged CABOMETYX at +8,400%. Is that real?
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

-- The eight most-reported drugs (ties broken by name).
CREATE OR REPLACE TABLE top_drugs AS
SELECT drug_name, COUNT(*) AS reports
FROM events
GROUP BY drug_name
ORDER BY reports DESC, drug_name
LIMIT 8;

-- Reports per drug and quarter. A quarter with no reports has NO ROW.
CREATE OR REPLACE TABLE drug_quarters AS
SELECT e.drug_name,
       CAST(date_trunc('quarter', e.report_date) AS DATE) AS qtr,
       COUNT(*) AS reports
FROM events AS e
WHERE e.drug_name IN (SELECT drug_name FROM top_drugs)
GROUP BY e.drug_name, qtr;

-- The first draft: LAG over the rows that exist.
CREATE OR REPLACE TABLE draft AS
SELECT drug_name, qtr, reports,
       LAG(reports) OVER (PARTITION BY drug_name ORDER BY qtr)
                                                    AS prev_reports
FROM drug_quarters;

-- The fix: a calendar of all 8 quarters, one row per drug and
-- quarter (CROSS JOIN), then the real counts joined on, 0 where
-- a quarter had none.
CREATE OR REPLACE TABLE full_grid AS
WITH calendar AS (
    SELECT DISTINCT CAST(date_trunc('quarter', report_date) AS DATE)
                                                         AS qtr
    FROM events
)
SELECT t.drug_name, c.qtr, COALESCE(d.reports, 0) AS reports
FROM top_drugs AS t
CROSS JOIN calendar AS c
LEFT JOIN drug_quarters AS d
       ON d.drug_name = t.drug_name AND d.qtr = c.qtr;

CREATE OR REPLACE TABLE fixed AS
SELECT drug_name, qtr, reports,
       LAG(reports) OVER (PARTITION BY drug_name ORDER BY qtr)
                                                    AS prev_reports
FROM full_grid;

-- Result 1. CABOMETYX in the draft: only 3 rows, so LAG compares
-- 2026 Q1 with 2025 Q3 and calls it the previous quarter.
SELECT strftime(qtr, '%Y') || ' Q' || quarter(qtr) AS quarter_label,
       reports, prev_reports,
       round(100.0 * (reports - prev_reports) / prev_reports, 1)
                                                   AS pct_change
FROM draft
WHERE drug_name = 'CABOMETYX'
ORDER BY qtr;

-- Result 2. CABOMETYX on the full calendar. NULLIF turns a previous
-- quarter of 0 into NULL, so the change is NULL (no base to compare
-- with) instead of inf.
SELECT strftime(qtr, '%Y') || ' Q' || quarter(qtr) AS quarter_label,
       reports, prev_reports,
       round(100.0 * (reports - prev_reports)
                   / NULLIF(prev_reports, 0), 1)   AS pct_change
FROM fixed
WHERE drug_name = 'CABOMETYX'
ORDER BY qtr;

-- Result 3. Row counts: the grid must be 8 drugs x 8 quarters, and
-- the grid's reports must add up to the drugs' reports.
SELECT (SELECT COUNT(*) FROM drug_quarters)  AS draft_rows,
       (SELECT COUNT(*) FROM full_grid)      AS grid_rows,
       (SELECT SUM(reports) FROM full_grid)  AS grid_reports,
       (SELECT SUM(reports) FROM top_drugs)  AS top8_reports;

-- Result 4. The alert, done right: quarters that more than doubled
-- on a quarter that had reports, plus quarters that start from 0
-- (no percentage possible; listed separately).
SELECT drug_name,
       strftime(qtr, '%Y') || ' Q' || quarter(qtr) AS quarter_label,
       prev_reports, reports,
       CASE WHEN prev_reports = 0 THEN 'from zero'
            ELSE '+' || CAST(round(100.0 * (reports - prev_reports)
                                   / prev_reports, 1) AS VARCHAR)
                     || '%'
       END AS change
FROM fixed
WHERE prev_reports IS NOT NULL
  AND reports > 0
  AND (prev_reports = 0 OR reports > 2 * prev_reports)
ORDER BY drug_name, qtr;

-- Result 5. How the two versions' alerts compare.
SELECT 'draft (rows that exist)' AS version,
       COUNT(*) FILTER (WHERE reports > 2 * prev_reports) AS doubled
FROM draft
UNION ALL
SELECT 'fixed (full calendar)',
       COUNT(*) FILTER (WHERE prev_reports > 0
                          AND reports > 2 * prev_reports)
FROM fixed;
