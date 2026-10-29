-- ============================================================
-- Session 3.3 · Assignment 3 (Advanced) · Solution
-- "One Curated File Every Team Can Trust"
-- Business question: build data/processed/events_curated.parquet,
-- with the report date as a DATE, seriousness as TRUE/FALSE and
-- every age converted to years, and prove the file is complete and
-- that the conversion changes the answers people get.
-- ============================================================

CREATE OR REPLACE MACRO repo_file(p) AS
    current_setting('file_search_path') || '/' || p;

CREATE OR REPLACE VIEW events AS
SELECT *
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

-- The curated table. openFDA age units: 800 decade, 801 year,
-- 802 month, 803 week, 804 day, 805 hour. An unknown unit gives NULL,
-- never a guess. A year is 365.25 days.
CREATE OR REPLACE TABLE curated AS
SELECT safety_report_id,
       drug_name,
       reaction,
       CASE serious WHEN '1' THEN true WHEN '2' THEN false END
           AS is_serious,
       patient_age,
       patient_age_unit,
       ROUND(CASE patient_age_unit
                 WHEN '800' THEN patient_age * 10
                 WHEN '801' THEN patient_age
                 WHEN '802' THEN patient_age / 12
                 WHEN '803' THEN patient_age / 52.18
                 WHEN '804' THEN patient_age / 365.25
                 WHEN '805' THEN patient_age / 8766
             END, 1) AS age_years,
       country,
       CAST(strptime(event_date, '%Y%m%d') AS DATE) AS report_date
FROM events
ORDER BY safety_report_id;

COPY curated TO (repo_file('data/processed/events_curated.parquet'))
    (FORMAT parquet);

-- Result 1. Completeness: the file holds every source report once,
-- and every age that had a unit got a value in years.
SELECT (SELECT COUNT(*) FROM events) AS source,
       COUNT(*) AS in_file,
       COUNT(DISTINCT safety_report_id) AS ids,
       COUNT(patient_age) AS ages,
       COUNT(age_years) AS in_years,
       COUNT(is_serious) AS serious_known
FROM 'data/processed/events_curated.parquet';

-- Result 2. The conversion, unit by unit: the raw age against the
-- age in years. The raw average mixes units.
SELECT COALESCE(patient_age_unit, 'none') AS unit,
       COUNT(*) AS reports,
       ROUND(AVG(patient_age), 1) AS avg_raw_age,
       ROUND(AVG(age_years), 1) AS avg_years,
       MAX(age_years) AS oldest_years
FROM 'data/processed/events_curated.parquet'
GROUP BY unit
ORDER BY reports DESC, unit;

-- Result 3. What changes for someone who asks "how old are the
-- patients?": the same question on the raw age and on age_years.
SELECT ROUND(AVG(patient_age), 1) AS avg_raw_age,
       ROUND(AVG(age_years), 1) AS avg_age_years,
       MEDIAN(age_years) AS median_age_years,
       COUNT(*) FILTER (WHERE patient_age >= 65) AS raw_65_plus,
       COUNT(*) FILTER (WHERE age_years >= 65) AS years_65_plus
FROM 'data/processed/events_curated.parquet';

-- Result 4. Seriousness as TRUE/FALSE, with the unknowns kept as NULL.
SELECT is_serious, COUNT(*) AS reports
FROM 'data/processed/events_curated.parquet'
GROUP BY is_serious
ORDER BY is_serious NULLS LAST;

-- Result 5. The types the next team gets, with no options.
SELECT column_name, column_type
FROM (DESCRIBE SELECT * FROM 'data/processed/events_curated.parquet');
