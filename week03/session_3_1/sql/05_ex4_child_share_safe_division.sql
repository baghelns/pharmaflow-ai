-- ============================================================
-- Session 3.1 · Exercise 4 · Corporate Scenario
-- "Why Is a Nasal Spray Top of the Children's List?"
-- Business question: for every drug with 50 or more reports, what
-- share of the reports with an age recorded in years are children
-- (under 18)? Rank the drugs, and never divide by zero silently.
-- Data: data/raw/adverse_events_10k.csv (6,218 reports)
-- patient_age_unit '801' means the age is in years.
-- ============================================================

CREATE OR REPLACE VIEW events AS
SELECT *
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

-- Result 1. The draft query from the dashboard. A drug with no ages in
--    years divides 0 by 0. DuckDB 2.0 returns NaN instead of an
--    error, and NaN sorts ABOVE every number with DESC.
SELECT drug_name,
       COUNT(*) AS reports,
       SUM(CASE WHEN patient_age_unit = '801'
                THEN 1 ELSE 0 END) AS aged_in_years,
       SUM(CASE WHEN patient_age_unit = '801' AND patient_age < 18
                THEN 1 ELSE 0 END) AS children,
       SUM(CASE WHEN patient_age_unit = '801' AND patient_age < 18
                THEN 1 ELSE 0 END)
         / SUM(CASE WHEN patient_age_unit = '801'
                    THEN 1 ELSE 0 END) AS child_share
FROM events
GROUP BY drug_name
HAVING COUNT(*) >= 50
ORDER BY child_share DESC, drug_name
LIMIT 5;

-- Result 2. The fix. NULLIF(x, 0) turns a 0 denominator into NULL, and
--    anything divided by NULL is NULL, which sorts last. COALESCE
--    then writes a label a reader understands.
SELECT drug_name,
       reports,
       aged_in_years,
       children,
       COALESCE(CAST(ROUND(100.0 * children
                           / NULLIF(aged_in_years, 0), 1) AS VARCHAR),
                'no ages in years') AS pct_children
FROM (SELECT drug_name,
             COUNT(*) AS reports,
             SUM(CASE WHEN patient_age_unit = '801'
                      THEN 1 ELSE 0 END) AS aged_in_years,
             SUM(CASE WHEN patient_age_unit = '801'
                       AND patient_age < 18
                      THEN 1 ELSE 0 END) AS children
      FROM events
      GROUP BY drug_name
      HAVING COUNT(*) >= 50) AS per_drug
ORDER BY 100.0 * children / NULLIF(aged_in_years, 0) DESC,
         drug_name
LIMIT 8;

-- Result 3. Which drugs have no ages in years at all?
SELECT drug_name, COUNT(*) AS reports
FROM events
GROUP BY drug_name
HAVING COUNT(*) >= 50
   AND SUM(CASE WHEN patient_age_unit = '801' THEN 1 ELSE 0 END) = 0;
