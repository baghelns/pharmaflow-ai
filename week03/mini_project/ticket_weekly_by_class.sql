-- ============================================================
-- PharmaFlow SQL Library · ticket_weekly_by_class.sql
-- Question : Ticket PHF-311: weekly adverse event counts by drug class
--            for the last 12 months.
-- Asked by : Safety Analyst, Pharmacovigilance (Week 3 Mini Project)
-- Source   : data/raw/adverse_events_10k.csv + data/raw/drug_reference.csv
--            (join on drug_name)
-- Output   : data/processed/ticket_weekly_by_class.parquet (9,152 rows: 52
--            weeks x 176 classes)
-- Checked  : 52 weeks from 2025-06-09 to 2026-06-01; 21 weeks sampled, 31
--            not; 3,154 reports; No class 1,012
-- Notes    : "Last 12 months" = the 52 whole weeks (Monday to Sunday) up to
--            the week of the latest report. reports is NULL in a week the
--            sample never looked at, and 0 in a sampled week with no report
--            of that class. The sample holds about 4 days a month, so these
--            counts describe the sample, not reporting volume.
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

CREATE OR REPLACE VIEW drug_classes AS
SELECT * FROM read_csv('data/raw/drug_reference.csv');

-- Step 1. Every report with its week and its class. date_trunc('week')
-- gives the Monday of the week. LEFT JOIN keeps the drugs that have no
-- class in drug_reference.csv, labelled 'No class'.
CREATE OR REPLACE TABLE report_weeks AS
SELECT e.safety_report_id,
       e.report_date,
       CAST(date_trunc('week', e.report_date) AS DATE) AS week_start,
       COALESCE(d.drug_class, 'No class') AS drug_class
FROM events AS e
LEFT JOIN drug_classes AS d ON e.drug_name = d.drug_name;

-- Step 2. The calendar: all 52 weeks, made with generate_series, not
-- taken from the data. SELECT DISTINCT week_start would list only the
-- weeks that have reports, and the empty weeks would vanish.
-- generate_series includes its last value and returns TIMESTAMPs.
CREATE OR REPLACE TABLE calendar AS
SELECT CAST(week_start AS DATE) AS week_start
FROM generate_series(
         (SELECT MAX(week_start) FROM report_weeks) - INTERVAL 51 WEEK,
         (SELECT MAX(week_start) FROM report_weeks),
         INTERVAL 1 WEEK) AS t(week_start);

-- Step 3. How many days the sample holds in each week. 0 means the
-- sample never looked at that week.
CREATE OR REPLACE TABLE week_coverage AS
SELECT c.week_start,
       COUNT(DISTINCT r.report_date) AS days_sampled
FROM calendar AS c
LEFT JOIN report_weeks AS r ON r.week_start = c.week_start
GROUP BY c.week_start;

-- Step 4. The answer: one row per week and class (CROSS JOIN), with the
-- counts LEFT JOINed on. A week with no sampled day gets NULL ("we did
-- not look"), a sampled week with no report of that class gets 0.
CREATE OR REPLACE TABLE answer AS
WITH classes AS (
    SELECT DISTINCT drug_class
    FROM report_weeks
    WHERE week_start IN (SELECT week_start FROM calendar)
), counts AS (
    SELECT week_start, drug_class, COUNT(*) AS n
    FROM report_weeks
    GROUP BY week_start, drug_class
)
SELECT w.week_start,
       w.days_sampled,
       k.drug_class,
       CASE WHEN w.days_sampled = 0 THEN NULL
            ELSE COALESCE(n.n, 0) END AS reports
FROM week_coverage AS w
CROSS JOIN classes AS k
LEFT JOIN counts AS n
       ON n.week_start = w.week_start AND n.drug_class = k.drug_class
ORDER BY w.week_start, k.drug_class;

-- Save the answer for the analyst.
COPY answer
TO (repo_file('data/processed/ticket_weekly_by_class.parquet'))
    (FORMAT parquet);

-- Result 1. Check, read back from the Parquet file: the grid has every
-- week and every class, and its total matches the reports in the window.
SELECT COUNT(DISTINCT week_start) AS weeks,
       MIN(week_start) AS first_week,
       MAX(week_start) AS last_week,
       COUNT(DISTINCT week_start) FILTER (WHERE days_sampled > 0)
           AS sampled,
       COUNT(DISTINCT drug_class) AS classes,
       COUNT(*) AS rows,
       CAST(SUM(reports) AS INTEGER) AS in_file,
       (SELECT COUNT(*) FROM report_weeks
        WHERE week_start >= (SELECT MIN(week_start) FROM calendar))
           AS window
FROM read_parquet('data/processed/ticket_weekly_by_class.parquet');

-- Result 2. The four named classes with the most reports in the
-- window, numbered for Result 3.
CREATE OR REPLACE TABLE top_classes AS
WITH ranked AS (
    SELECT drug_class,
           CAST(SUM(reports) AS INTEGER) AS reports,
           COUNT(*) FILTER (WHERE reports > 0) AS weeks_with_reports,
           ROW_NUMBER() OVER (ORDER BY SUM(reports) DESC, drug_class) AS rk
    FROM answer
    WHERE drug_class <> 'No class'
    GROUP BY drug_class
)
SELECT * FROM ranked WHERE rk <= 4;

SELECT 'c' || rk AS col,
       CASE WHEN length(drug_class) > 40
            THEN left(drug_class, 39) || '…'
            ELSE drug_class END AS drug_class,
       reports,
       weeks_with_reports
FROM top_classes
ORDER BY rk;

-- Result 3. The weekly table the analyst asked for, shown wide: the four
-- classes from Result 2, every other named class, and No class. NULL =
-- the sample has no day in that week.
-- SUM of integers is a HUGEINT (int128); CAST keeps the table narrow.
SELECT a.week_start,
       ANY_VALUE(a.days_sampled) AS days,
       CAST(SUM(a.reports) AS INTEGER) AS total,
       CAST(SUM(a.reports) FILTER (WHERE t.rk = 1) AS INTEGER) AS c1,
       CAST(SUM(a.reports) FILTER (WHERE t.rk = 2) AS INTEGER) AS c2,
       CAST(SUM(a.reports) FILTER (WHERE t.rk = 3) AS INTEGER) AS c3,
       CAST(SUM(a.reports) FILTER (WHERE t.rk = 4) AS INTEGER) AS c4,
       CAST(SUM(a.reports) FILTER (WHERE t.rk IS NULL
                AND a.drug_class <> 'No class') AS INTEGER) AS other,
       CAST(SUM(a.reports) FILTER (WHERE a.drug_class = 'No class')
            AS INTEGER) AS no_class
FROM answer AS a
LEFT JOIN top_classes AS t ON t.drug_class = a.drug_class
GROUP BY a.week_start
ORDER BY a.week_start;

-- Result 4. Why the gaps: the sample holds a few days of every month,
-- and about the same number of reports each month (Session 2.1). Even
-- a monthly count describes how the sample was drawn.
SELECT strftime(report_date, '%Y-%m') AS month,
       COUNT(DISTINCT report_date) AS days_sampled,
       MIN(day(report_date)) AS first_day,
       MAX(day(report_date)) AS last_day,
       COUNT(*) AS reports
FROM report_weeks
WHERE week_start >= (SELECT MIN(week_start) FROM calendar)
GROUP BY month
ORDER BY month;

-- Result 5. Bulk submissions inside the window (the Week 2 rule: one
-- drug, at least half of its day's reports and at least 20). A spike
-- in a weekly series can be one batch.
WITH drug_days AS (
    SELECT e.report_date, e.drug_name, r.drug_class, COUNT(*) AS reports
    FROM events AS e
    JOIN report_weeks AS r USING (safety_report_id)
    WHERE r.week_start >= (SELECT MIN(week_start) FROM calendar)
    GROUP BY e.report_date, e.drug_name, r.drug_class
), shares AS (
    SELECT *,
           100.0 * reports / SUM(reports) OVER (PARTITION BY report_date)
               AS pct_of_day
    FROM drug_days
)
SELECT report_date,
       drug_name,
       CASE WHEN length(drug_class) > 30
            THEN left(drug_class, 29) || '…'
            ELSE drug_class END AS drug_class,
       reports,
       ROUND(pct_of_day, 1) AS pct_of_day
FROM shares
WHERE pct_of_day >= 50 AND reports >= 20
ORDER BY report_date, drug_name;
