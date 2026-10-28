-- ============================================================
-- Session 3.1 · Assignment 2 (Intermediate)
-- "Where Do Each Drug Class's Reports Come From?"
-- For every drug class with more than 100 reports: the share from
-- the US, from outside the US and with no country, and the serious
-- share. Every block loads its own data, so it runs on its own.
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

-- Result 1. One row per large class; the four value columns are
-- percentages. The location shares add up to 100 because each CASE
-- puts every report in exactly one place. Long class names are cut
-- to 30 characters for display only (class_label); the grouping
-- uses the full name.
SELECT CASE WHEN length(r.drug_class) > 30
            THEN left(r.drug_class, 29) || '…'
            ELSE r.drug_class END                 AS class_label,
       COUNT(*)                                   AS reports,
       ROUND(100.0 * SUM(CASE WHEN e.country = 'US'
                              THEN 1 ELSE 0 END) / COUNT(*), 1) AS us,
       ROUND(100.0 * SUM(CASE WHEN e.country <> 'US'
                              THEN 1 ELSE 0 END) / COUNT(*), 1) AS non_us,
       ROUND(100.0 * SUM(CASE WHEN e.country IS NULL
                              THEN 1 ELSE 0 END) / COUNT(*), 1)
                                                  AS no_country,
       ROUND(100.0 * SUM(CASE WHEN e.serious = '1' THEN 1 ELSE 0 END)
             / NULLIF(COUNT(e.serious), 0), 1)    AS serious
FROM events AS e
INNER JOIN drug_ref AS r ON e.drug_name = r.drug_name
GROUP BY r.drug_class
HAVING COUNT(*) > 100
ORDER BY reports DESC, r.drug_class;

-- Result 2. Check: every report in these classes is counted once.
SELECT SUM(reports) AS reports_in_classes,
       SUM(us + non_us + unknown) AS placed
FROM (SELECT COUNT(*) AS reports,
             SUM(CASE WHEN e.country = 'US' THEN 1 ELSE 0 END) AS us,
             SUM(CASE WHEN e.country <> 'US' THEN 1 ELSE 0 END) AS non_us,
             SUM(CASE WHEN e.country IS NULL THEN 1 ELSE 0 END) AS unknown
      FROM events AS e
      INNER JOIN drug_ref AS r ON e.drug_name = r.drug_name
      GROUP BY r.drug_class
      HAVING COUNT(*) > 100) AS per_class;
