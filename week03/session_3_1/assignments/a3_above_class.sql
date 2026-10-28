-- ============================================================
-- Session 3.1 · Assignment 3 (Advanced)
-- "Which Drugs Are Serious More Often Than Their Own Class?"
-- For drugs with 20 or more reports: compare each drug's serious
-- share with its whole class's serious share, and list the ten
-- biggest gaps. Every block loads its own data, so it runs on its own.
-- ============================================================

CREATE OR REPLACE VIEW events AS
SELECT *
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

CREATE OR REPLACE VIEW drug_ref AS
SELECT * FROM read_csv('data/raw/drug_reference.csv');

-- One row per drug: reports, reports with seriousness recorded,
-- serious reports, and its class.
CREATE OR REPLACE TABLE per_drug AS
SELECT r.drug_class,
       e.drug_name,
       COUNT(*)                                        AS reports,
       COUNT(e.serious)                                AS recorded,
       SUM(CASE WHEN e.serious = '1' THEN 1 ELSE 0 END) AS serious
FROM events AS e
INNER JOIN drug_ref AS r ON e.drug_name = r.drug_name
GROUP BY r.drug_class, e.drug_name;

-- Result 1. The ten biggest gaps, in percentage points. An inline
-- subquery computes each class's serious share once (all its drugs
-- together); the join attaches it to every drug in that class.
-- class_label cuts long class names to 26 characters for display.
SELECT CASE WHEN length(d.drug_class) > 26
            THEN left(d.drug_class, 25) || '…'
            ELSE d.drug_class END                          AS class_label,
       d.drug_name,
       d.reports,
       ROUND(100.0 * d.serious / NULLIF(d.recorded, 0), 1) AS drug_pct,
       ROUND(c.pct_class, 1)                               AS class_pct,
       ROUND(100.0 * d.serious / NULLIF(d.recorded, 0)
             - c.pct_class, 1)                             AS gap
FROM per_drug AS d
INNER JOIN (SELECT drug_class,
                   100.0 * SUM(serious) / NULLIF(SUM(recorded), 0)
                       AS pct_class
            FROM per_drug
            GROUP BY drug_class) AS c
        ON c.drug_class = d.drug_class
WHERE d.reports >= 20
  AND 100.0 * d.serious / NULLIF(d.recorded, 0) > c.pct_class
ORDER BY gap DESC, d.drug_name
LIMIT 10;

-- Result 2. The same comparison with a correlated subquery, which
-- recomputes the class share for each drug's own class: how many
-- drugs qualify (20+ reports), and how many beat their class?
SELECT COUNT(*) AS drugs_with_20_plus,
       SUM(CASE WHEN 100.0 * d.serious / NULLIF(d.recorded, 0)
                     > (SELECT 100.0 * SUM(p.serious)
                               / NULLIF(SUM(p.recorded), 0)
                        FROM per_drug AS p
                        WHERE p.drug_class = d.drug_class)
                THEN 1 ELSE 0 END) AS above_their_class
FROM per_drug AS d
WHERE d.reports >= 20;
