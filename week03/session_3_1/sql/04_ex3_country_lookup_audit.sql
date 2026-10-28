-- ============================================================
-- Session 3.1 · Exercise 3 · Advanced
-- "Audit the Country Lookup Both Ways"
-- Business question: which country codes in our reports are
-- missing from country_codes.csv, and which lookup rows never
-- match a report?
-- Data: data/raw/adverse_events_10k.csv and
--       data/raw/country_codes.csv (54 rows)
-- ============================================================

CREATE OR REPLACE VIEW events AS
SELECT *
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

CREATE OR REPLACE VIEW countries AS
SELECT * FROM read_csv('data/raw/country_codes.csv');

-- One row per country code that appears in the reports.
CREATE OR REPLACE VIEW report_countries AS
SELECT country, COUNT(*) AS reports
FROM events
WHERE country IS NOT NULL
GROUP BY country;

-- Result 1. FULL OUTER JOIN keeps codes from BOTH sides, so each code is
--    'both', 'reports only' or 'lookup only'.
SELECT CASE
           WHEN r.country IS NULL      THEN 'lookup only'
           WHEN c.country_code IS NULL THEN 'reports only'
           ELSE 'both'
       END                        AS found_in,
       COUNT(*)                   AS codes,
       COALESCE(SUM(r.reports), 0) AS reports
FROM report_countries AS r
FULL OUTER JOIN countries AS c ON r.country = c.country_code
GROUP BY found_in
ORDER BY found_in;

-- Result 2. Codes in the reports but not in the lookup, biggest first.
--    LEFT JOIN + "right side IS NULL" is the classic anti-join.
SELECT r.country, r.reports
FROM report_countries AS r
LEFT JOIN countries AS c ON r.country = c.country_code
WHERE c.country_code IS NULL
ORDER BY r.reports DESC, r.country
LIMIT 8;

-- Result 3. Lookup rows that never match a report.
SELECT c.country_code, c.country_name, c.business_region
FROM countries AS c
LEFT JOIN report_countries AS r ON r.country = c.country_code
WHERE r.country IS NULL
ORDER BY c.country_code;
