-- ============================================================
-- PharmaFlow SQL Library · 04_reports_by_region.sql
-- Question : How many reports come from each business region?
-- Asked by : Regulatory Affairs (Sessions 1.2 and 3.1)
-- Source   : data/raw/adverse_events_10k.csv + data/raw/country_codes.csv
--            (join on country = country_code)
-- Output   : data/processed/library/04_reports_by_region.parquet (6 rows)
-- Checked  : North America 4,404 (70.8%), EMEA 522, APAC 437, no country 403,
--            code not in lookup 321, LATAM 131
-- Notes    : LEFT JOIN: reports whose code is not in the lookup (EU the
--            largest) and reports with no country are kept and labelled.
-- ============================================================

-- COPY writes relative to the folder you run from; repo_file()
-- builds the path from the repo root (Session 3.3).
CREATE OR REPLACE MACRO repo_file(p) AS
    current_setting('file_search_path') || '/' || p;

CREATE OR REPLACE VIEW events AS
SELECT *,
       CAST(strptime(event_date, '%Y%m%d') AS DATE) AS report_date
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

CREATE OR REPLACE VIEW countries AS
SELECT * FROM read_csv('data/raw/country_codes.csv');

CREATE OR REPLACE TABLE answer AS
SELECT CASE WHEN e.country IS NULL THEN 'No country recorded'
            WHEN c.business_region IS NULL THEN 'Code not in lookup'
            ELSE c.business_region END AS region,
       COUNT(*) AS reports,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_reports,
       ROUND(100.0 * COUNT(*) FILTER (WHERE e.serious = '1')
             / COUNT(e.serious), 1) AS pct_serious
FROM events AS e
LEFT JOIN countries AS c ON e.country = c.country_code
GROUP BY region;

-- Save the answer for other teams.
COPY answer
TO (repo_file('data/processed/library/04_reports_by_region.parquet'))
    (FORMAT parquet);

-- Show the answer.
SELECT * FROM answer ORDER BY reports DESC, region;
