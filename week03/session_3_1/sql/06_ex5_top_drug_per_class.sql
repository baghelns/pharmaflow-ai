-- ============================================================
-- Session 3.1 · Exercise 5 · Interview Challenge
-- "Top Drug in Every Class -- Ties Included, No Window Functions"
-- Rules: no window functions (no OVER), no LIMIT per group, every
-- tied drug must be returned, and the query must work (return no
-- rows, not an error) on an empty table.
-- Data: data/raw/adverse_events_10k.csv and
--       data/raw/drug_reference.csv (521 drugs, one class each)
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

-- Reports per drug, with its class. An INNER JOIN is right here:
-- a drug with no class cannot be "top of its class".
CREATE OR REPLACE TABLE drug_counts AS
SELECT r.drug_class, e.drug_name, COUNT(*) AS reports
FROM events AS e
INNER JOIN drug_ref AS r ON e.drug_name = r.drug_name
GROUP BY r.drug_class, e.drug_name;

-- The answer. The inner query is CORRELATED: it runs once per
--    outer row and uses that row's class (d.drug_class).
CREATE OR REPLACE VIEW top_per_class AS
SELECT d.drug_class, d.drug_name, d.reports
FROM drug_counts AS d
WHERE d.reports = (SELECT MAX(d2.reports)
                   FROM drug_counts AS d2
                   WHERE d2.drug_class = d.drug_class);

-- Result 1. Check the size of the answer: more rows than classes = ties.
SELECT (SELECT COUNT(DISTINCT drug_class) FROM drug_counts) AS classes,
       (SELECT COUNT(*) FROM top_per_class)                AS rows;

-- Result 2. The eight biggest classes (100+ reports in total).
SELECT t.drug_class, t.drug_name, t.reports
FROM top_per_class AS t
WHERE t.drug_class IN (SELECT drug_class
                       FROM drug_counts
                       GROUP BY drug_class
                       HAVING SUM(reports) > 100)
ORDER BY t.reports DESC, t.drug_name;

-- Result 3. The ties: classes with more than one top drug, biggest first.
SELECT drug_class, COUNT(*) AS tied_drugs, MAX(reports) AS reports
FROM top_per_class
GROUP BY drug_class
HAVING COUNT(*) > 1
ORDER BY reports DESC, tied_drugs DESC, drug_class
LIMIT 5;

-- Result 4. The biggest tie, drug by drug.
SELECT drug_class, drug_name, reports
FROM top_per_class
WHERE drug_class = 'Endothelin Receptor Antagonist'
ORDER BY drug_name;

-- Result 5. How many classes have a tie at all?
SELECT COUNT(*) AS classes_with_a_tie
FROM (SELECT drug_class
      FROM top_per_class
      GROUP BY drug_class
      HAVING COUNT(*) > 1) AS tied;

-- Result 6. The empty-table rule: same query on a copy with no rows.
CREATE OR REPLACE TABLE empty_counts AS
SELECT * FROM drug_counts WHERE FALSE;

SELECT COUNT(*) AS rows_on_empty_table
FROM empty_counts AS d
WHERE d.reports = (SELECT MAX(d2.reports)
                   FROM empty_counts AS d2
                   WHERE d2.drug_class = d.drug_class);
