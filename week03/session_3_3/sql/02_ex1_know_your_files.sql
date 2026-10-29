-- ============================================================
-- Session 3.3 · Exercise 1 · Beginner
-- "Know Your Files Before You Combine Them"
-- Business question: data/raw holds Week 1's JSON file and Week 2's
-- CSV. Without importing anything, what does each file contain:
-- columns and types, rows, dates and completeness? Do they overlap?
-- Data: data/raw/adverse_events_10k.csv (6,218 reports)
--       data/raw/adverse_events_1000.json (1,000 reports)
-- ============================================================

-- Result 1. A file can be queried like a table: put its path in
-- quotes after FROM. DuckDB picks the reader from the extension.
SELECT 'adverse_events_10k.csv' AS file, COUNT(*) AS reports
FROM 'data/raw/adverse_events_10k.csv'
UNION ALL
SELECT 'adverse_events_1000.json', COUNT(*)
FROM 'data/raw/adverse_events_1000.json';

-- Result 2. Every column and its type: the CSV read with no options
-- (DuckDB guesses), the CSV read with the types we choose, and the
-- JSON. FULL JOIN keeps a column that only one file has.
WITH csv_guessed AS (
    SELECT column_name, column_type
    FROM (DESCRIBE SELECT * FROM 'data/raw/adverse_events_10k.csv')
), csv_typed AS (
    SELECT column_name, column_type
    FROM (DESCRIBE SELECT *
          FROM read_csv('data/raw/adverse_events_10k.csv',
                        types = {'safety_report_id': 'VARCHAR',
                                 'serious': 'VARCHAR',
                                 'patient_age_unit': 'VARCHAR',
                                 'event_date': 'VARCHAR'}))
), from_json AS (
    SELECT column_name, column_type
    FROM (DESCRIBE SELECT * FROM 'data/raw/adverse_events_1000.json')
)
SELECT COALESCE(g.column_name, j.column_name) AS column_name,
       g.column_type AS csv_guessed,
       t.column_type AS csv_with_types,
       j.column_type AS json
FROM csv_guessed g
JOIN csv_typed t USING (column_name)
FULL JOIN from_json j USING (column_name)
ORDER BY column_name;

-- The two files as views, IDs and dates kept as text.
CREATE OR REPLACE VIEW csv_reports AS
SELECT *
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

CREATE OR REPLACE VIEW json_reports AS
SELECT * FROM read_json('data/raw/adverse_events_1000.json');

-- Result 3. Size and dates of each file. Every ID is different in
-- both files (ids = reports).
SELECT 'csv' AS source, COUNT(*) AS reports,
       COUNT(DISTINCT safety_report_id) AS ids,
       MIN(event_date) AS first_day, MAX(event_date) AS last_day,
       COUNT(DISTINCT drug_name) AS drugs
FROM csv_reports
UNION ALL
SELECT 'json', COUNT(*), COUNT(DISTINCT safety_report_id),
       MIN(event_date), MAX(event_date), COUNT(DISTINCT drug_name)
FROM json_reports;

-- Result 4. Completeness, in percent. COUNT(column) counts the
-- rows where that column is not blank; the serious share is taken
-- over the reports that have a serious code.
SELECT 'csv' AS source,
       ROUND(100.0 * COUNT(*) FILTER (WHERE serious = '1')
             / COUNT(serious), 1) AS pct_serious,
       ROUND(100.0 * COUNT(patient_age) / COUNT(*), 1) AS pct_with_age,
       ROUND(100.0 * COUNT(country) / COUNT(*), 1) AS pct_with_country
FROM csv_reports
UNION ALL
SELECT 'json',
       ROUND(100.0 * COUNT(*) FILTER (WHERE serious = '1')
             / COUNT(serious), 1),
       ROUND(100.0 * COUNT(patient_age) / COUNT(*), 1),
       ROUND(100.0 * COUNT(country) / COUNT(*), 1)
FROM json_reports;

-- Result 5. Do the files share any report? Count the IDs in both.
SELECT COUNT(*) AS ids_in_both_files
FROM csv_reports c
JOIN json_reports j USING (safety_report_id);
