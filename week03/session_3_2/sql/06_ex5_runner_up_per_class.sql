-- ============================================================
-- Session 3.2 · Exercise 5 · Interview Challenge
-- "The Runner-Up in Every Drug Class"
-- Rules: for each drug class, return the drug(s) with the second-
-- highest report count. Ties at second place all come back; a class
-- whose drugs all have the same count has no runner-up and returns
-- nothing; no LIMIT, no correlated subquery; and the query must
-- return 0 rows (not an error) on an empty table.
-- Data: data/raw/adverse_events_10k.csv and
--       data/raw/drug_reference.csv (521 drugs, one class each)
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

-- Reports per drug, with its class (INNER JOIN: a drug with no class
-- cannot be second in its class).
CREATE OR REPLACE TABLE drug_counts AS
SELECT r.drug_class, e.drug_name, COUNT(*) AS reports
FROM events AS e
INNER JOIN drug_ref AS r ON e.drug_name = r.drug_name
GROUP BY r.drug_class, e.drug_name;

-- The answer. DENSE_RANK gives the second-highest COUNT the number 2
-- even when two drugs tie for first. class_reports (the class's total,
-- another window) is only there to sort and filter the display.
CREATE OR REPLACE VIEW runner_up AS
WITH ranked AS (
    SELECT drug_class, drug_name, reports,
           DENSE_RANK() OVER (PARTITION BY drug_class
                              ORDER BY reports DESC) AS dense_rnk,
           SUM(reports) OVER (PARTITION BY drug_class) AS class_reports
    FROM drug_counts
)
SELECT drug_class, drug_name, reports, class_reports
FROM ranked
WHERE dense_rnk = 2;

-- Result 1. Size of the answer, and the checks behind it: a class
-- needs at least two DIFFERENT counts to have a runner-up.
SELECT (SELECT COUNT(DISTINCT drug_class) FROM drug_counts)
                                              AS classes,
       (SELECT COUNT(*) FROM (SELECT drug_class FROM drug_counts
                              GROUP BY drug_class
                              HAVING COUNT(DISTINCT reports) >= 2))
                                              AS classes_with_2_counts,
       (SELECT COUNT(DISTINCT drug_class) FROM runner_up)
                                              AS classes_answered,
       (SELECT COUNT(*) FROM runner_up)       AS rows_returned;

-- Result 2. The runner-up in the eight biggest classes (100+ reports).
SELECT CASE WHEN length(u.drug_class) > 30
            THEN left(u.drug_class, 29) || '…'
            ELSE u.drug_class END AS class_label,
       u.drug_name, u.reports, u.class_reports
FROM runner_up AS u
WHERE u.class_reports > 100
ORDER BY u.class_reports DESC, u.drug_class, u.drug_name;

-- Result 3. Why not RANK or ROW_NUMBER? Count what "= 2" returns.
WITH ranked AS (
    SELECT drug_class, drug_name, reports,
           ROW_NUMBER() OVER (PARTITION BY drug_class
                              ORDER BY reports DESC, drug_name) AS rn,
           RANK()       OVER (PARTITION BY drug_class
                              ORDER BY reports DESC) AS rnk,
           DENSE_RANK() OVER (PARTITION BY drug_class
                              ORDER BY reports DESC) AS drnk
    FROM drug_counts
)
SELECT 'ROW_NUMBER() = 2' AS method, COUNT(*) AS rows_returned,
       COUNT(DISTINCT drug_class) AS classes
FROM ranked WHERE rn = 2
UNION ALL
SELECT 'RANK() = 2', COUNT(*), COUNT(DISTINCT drug_class)
FROM ranked WHERE rnk = 2
UNION ALL
SELECT 'DENSE_RANK() = 2', COUNT(*), COUNT(DISTINCT drug_class)
FROM ranked WHERE drnk = 2
ORDER BY method;

-- Result 4. One class where only DENSE_RANK finds the runner-up:
-- two drugs tie for first, so RANK jumps from 1 to 3.
SELECT drug_name, reports,
       RANK()       OVER (ORDER BY reports DESC) AS rnk,
       DENSE_RANK() OVER (ORDER BY reports DESC) AS dense_rnk
FROM drug_counts
WHERE drug_class = 'Endothelin Receptor Antagonist'
ORDER BY reports DESC, drug_name;

-- Result 5. The empty-table rule: same query on a copy with no rows.
CREATE OR REPLACE TABLE empty_counts AS
SELECT * FROM drug_counts WHERE FALSE;

WITH ranked AS (
    SELECT drug_class, drug_name, reports,
           DENSE_RANK() OVER (PARTITION BY drug_class
                              ORDER BY reports DESC) AS dense_rnk
    FROM empty_counts
)
SELECT COUNT(*) AS rows_on_empty_table
FROM ranked
WHERE dense_rnk = 2;
