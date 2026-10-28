-- ============================================================
-- Session 3.1 · Exercise 2 · Intermediate
-- "How Complete Is Each Country's Data?"
-- Business question: for every country with 50 or more reports,
-- how many reports, how many record the patient's age, what share
-- that is, and the first and last report date in our sample.
-- Data: data/raw/adverse_events_10k.csv (6,218 reports)
-- ============================================================

CREATE OR REPLACE VIEW events AS
SELECT *
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

-- Result 1. COUNT(*) counts rows. COUNT(patient_age) counts only rows where
-- the age is not NULL. HAVING filters groups after counting.
SELECT COALESCE(country, 'Not reported')          AS country,
       COUNT(*)                                   AS reports,
       COUNT(patient_age)                         AS with_age,
       ROUND(100.0 * COUNT(patient_age) / COUNT(*), 1)
                                                  AS pct_with_age,
       MIN(event_date)                            AS first_report,
       MAX(event_date)                            AS last_report
FROM events
GROUP BY COALESCE(country, 'Not reported')
HAVING COUNT(*) >= 50
ORDER BY reports DESC, country;

-- Result 2. Check: the groups above plus the smaller groups add up to 6,218.
SELECT SUM(reports) AS all_reports,
       SUM(CASE WHEN reports >= 50 THEN reports ELSE 0 END)
                    AS in_groups_of_50_plus
FROM (SELECT country, COUNT(*) AS reports
      FROM events
      GROUP BY country) AS per_country;
