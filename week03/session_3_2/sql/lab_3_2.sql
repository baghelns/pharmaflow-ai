-- ============================================================
-- Session 3.2 · Lab · Reference solution (TRAINER USE ONLY)
-- Four window-function queries on the PharmaFlow reports.
-- ============================================================

CREATE OR REPLACE VIEW events AS
SELECT *,
       CAST(strptime(event_date, '%Y%m%d') AS DATE) AS report_date
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

CREATE OR REPLACE VIEW drug_ref AS
SELECT * FROM read_csv('data/raw/drug_reference.csv');

-- Query 1. Rank drugs by report count within each drug class.
-- (INNER JOIN: a drug with no class has no class to be ranked in.)
CREATE OR REPLACE TABLE class_ranks AS
WITH drug_counts AS (
    SELECT r.drug_class, e.drug_name, COUNT(*) AS reports
    FROM events AS e
    INNER JOIN drug_ref AS r ON e.drug_name = r.drug_name
    GROUP BY r.drug_class, e.drug_name
)
SELECT drug_class, drug_name, reports,
       RANK() OVER (PARTITION BY drug_class
                    ORDER BY reports DESC) AS rank_in_class
FROM drug_counts;

SELECT (SELECT COUNT(*) FROM class_ranks)                   AS ranked_drugs,
       (SELECT COUNT(DISTINCT drug_class) FROM class_ranks) AS classes,
       (SELECT COUNT(*) FROM class_ranks
        WHERE rank_in_class = 1)                            AS rank_1_rows;

SELECT drug_name, reports, rank_in_class
FROM class_ranks
WHERE drug_class = 'Atypical Antipsychotic'
ORDER BY rank_in_class, drug_name;

-- Query 2. Quarter-on-quarter change in serious reports, using LAG.
WITH quarterly AS (
    SELECT CAST(date_trunc('quarter', report_date) AS DATE) AS qtr,
           COUNT(*) FILTER (WHERE serious = '1') AS serious_reports
    FROM events
    GROUP BY qtr
)
SELECT qtr, serious_reports,
       LAG(serious_reports) OVER (ORDER BY qtr) AS prev_quarter,
       round(100.0 * (serious_reports - LAG(serious_reports) OVER (ORDER BY qtr))
             / NULLIF(LAG(serious_reports) OVER (ORDER BY qtr), 0), 1)
                                                AS pct_change
FROM quarterly
ORDER BY qtr;

-- Query 3. Running total of reports by month.
WITH monthly AS (
    SELECT CAST(date_trunc('month', report_date) AS DATE) AS month_start,
           COUNT(*) AS reports
    FROM events
    GROUP BY month_start
)
SELECT strftime(month_start, '%Y-%m') AS month, reports,
       SUM(reports) OVER (ORDER BY month_start
                          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                AS running_total
FROM monthly
ORDER BY month_start;

-- Query 4. 3-month moving average of serious reports (NULL until the
-- window holds three months).
WITH monthly AS (
    SELECT CAST(date_trunc('month', report_date) AS DATE) AS month_start,
           COUNT(*) FILTER (WHERE serious = '1') AS serious_reports
    FROM events
    GROUP BY month_start
)
SELECT strftime(month_start, '%Y-%m') AS month, serious_reports,
       CASE WHEN COUNT(*) OVER w3 = 3
            THEN round(AVG(serious_reports) OVER w3, 1) END AS avg_3_months
FROM monthly
WINDOW w3 AS (ORDER BY month_start ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
ORDER BY month_start;
