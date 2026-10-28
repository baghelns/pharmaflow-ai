-- ============================================================
-- Session 3.1 · Assignment 1 (Beginner)
-- "Which Drugs Appear Most in Reports About Older Patients?"
-- Older patient = age recorded in years (patient_age_unit '801')
-- and 65 or over. Every block loads its own data, so it runs on
-- its own: that is why the CREATE VIEW repeats in each solution.
-- ============================================================

CREATE OR REPLACE VIEW events AS
SELECT *
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

-- Result 1. How many reports can we place by age at all?
SELECT COUNT(*)                                   AS reports,
       COUNT(patient_age)                         AS with_age,
       SUM(CASE WHEN patient_age_unit = '801'
                THEN 1 ELSE 0 END)                AS age_in_years,
       SUM(CASE WHEN patient_age_unit = '801' AND patient_age >= 65
                THEN 1 ELSE 0 END)                AS aged_65_plus
FROM events;

-- Result 2. The eight drugs with the most reports about patients 65+.
SELECT drug_name,
       COUNT(*)                                        AS reports_65_plus,
       SUM(CASE WHEN serious = '1' THEN 1 ELSE 0 END)  AS serious,
       ROUND(100.0 * SUM(CASE WHEN serious = '1' THEN 1 ELSE 0 END)
             / NULLIF(COUNT(serious), 0), 1)           AS pct_serious
FROM events
WHERE patient_age_unit = '801'
  AND patient_age >= 65
GROUP BY drug_name
ORDER BY reports_65_plus DESC, drug_name
LIMIT 8;
