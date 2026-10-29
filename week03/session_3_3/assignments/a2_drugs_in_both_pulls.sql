-- ============================================================
-- Session 3.3 · Assignment 2 (Intermediate) · Solution
-- "Which Drugs Appear in Both Pulls?"
-- Business question: Medical Affairs wants the drugs reported both
-- in Week 1's 2014 JSON pull and in Week 2's 2024-2026 CSV pull,
-- and asks whether their serious shares can be compared.
-- ============================================================

CREATE OR REPLACE VIEW csv_reports AS
SELECT *
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

CREATE OR REPLACE VIEW json_reports AS
SELECT * FROM read_json('data/raw/adverse_events_1000.json');

-- One cleaned name per drug: the JSON writes some names with a
-- " (UNKNOWN)" ending, which is not part of the drug's name.
CREATE OR REPLACE MACRO clean_name(n) AS
    trim(regexp_replace(n, ' \(UNKNOWN\)$', ''));

CREATE OR REPLACE TABLE per_drug AS
SELECT 'csv' AS source, clean_name(drug_name) AS drug,
       COUNT(*) AS reports,
       COUNT(*) FILTER (WHERE serious = '1') AS serious_reports,
       COUNT(serious) AS recorded
FROM csv_reports
GROUP BY drug
UNION ALL
SELECT 'json', clean_name(drug_name),
       COUNT(*), COUNT(*) FILTER (WHERE serious = '1'), COUNT(serious)
FROM json_reports
GROUP BY clean_name(drug_name);

-- Result 1. How many drugs each pull has, how many match exactly,
-- and how many match once the names are cleaned.
SELECT (SELECT COUNT(DISTINCT drug_name) FROM csv_reports) AS csv_drugs,
       (SELECT COUNT(DISTINCT drug_name) FROM json_reports) AS json_drugs,
       (SELECT COUNT(*) FROM (SELECT DISTINCT drug_name FROM csv_reports)
        JOIN (SELECT DISTINCT drug_name FROM json_reports)
        USING (drug_name)) AS exact_matches,
       (SELECT COUNT(*) FROM per_drug c JOIN per_drug j USING (drug)
        WHERE c.source = 'csv' AND j.source = 'json') AS cleaned_matches;

-- Result 2. The drugs that match only after cleaning.
SELECT j.drug_name AS json_name, clean_name(j.drug_name) AS cleaned
FROM (SELECT DISTINCT drug_name FROM json_reports) j
WHERE j.drug_name LIKE '% (UNKNOWN)'
  AND clean_name(j.drug_name) IN (SELECT drug_name FROM csv_reports)
  AND j.drug_name NOT IN (SELECT drug_name FROM csv_reports)
ORDER BY json_name;

-- Result 3. The shared drugs with the most CSV reports, side by side.
SELECT c.drug,
       c.reports AS csv_reports,
       ROUND(100.0 * c.serious_reports / c.recorded, 1) AS csv_pct,
       j.reports AS json_reports,
       ROUND(100.0 * j.serious_reports / j.recorded, 1) AS json_pct
FROM per_drug c
JOIN per_drug j USING (drug)
WHERE c.source = 'csv' AND j.source = 'json'
ORDER BY c.reports DESC, c.drug
LIMIT 10;

-- Result 4. Why the shares cannot be compared drug by drug: the JSON
-- allowed at most 4 reports per drug name (Session 1.2), so most
-- shared drugs have 1 to 4 JSON reports. (A drug can reach 6 after
-- cleaning, when a name and its "(UNKNOWN)" form are added together.)
SELECT j.reports AS json_reports_per_drug,
       COUNT(*) AS shared_drugs
FROM per_drug c
JOIN per_drug j USING (drug)
WHERE c.source = 'csv' AND j.source = 'json'
GROUP BY j.reports
ORDER BY j.reports;

-- Result 5. The shared drugs pooled: their reports and serious share
-- in each pull. Two samples drawn two ways, ten years apart.
SELECT c.source, SUM(c.reports) AS reports,
       ROUND(100.0 * SUM(c.serious_reports) / SUM(c.recorded), 1)
           AS pct_serious
FROM per_drug c
WHERE c.drug IN (SELECT drug FROM per_drug WHERE source = 'csv')
  AND c.drug IN (SELECT drug FROM per_drug WHERE source = 'json')
GROUP BY c.source
ORDER BY c.source;
