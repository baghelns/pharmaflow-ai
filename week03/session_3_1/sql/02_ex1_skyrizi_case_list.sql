-- ============================================================
-- Session 3.1 · Exercise 1 · Beginner · "The SKYRIZI Case List"
-- Business question: Medical Affairs wants the 10 most recent
-- serious SKYRIZI reports, and how many different reactions
-- SKYRIZI's serious reports describe.
-- Data: data/raw/adverse_events_10k.csv (6,218 reports)
-- ============================================================

-- IDs, codes and dates are labels, not numbers: load them as text.
CREATE OR REPLACE VIEW events AS
SELECT *
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

-- Result 1. How many SKYRIZI reports are there?
SELECT COUNT(*) AS skyrizi_reports
FROM events
WHERE drug_name = 'SKYRIZI';

-- Result 2. How many of them are serious?
SELECT COUNT(*) AS serious_skyrizi_reports
FROM events
WHERE drug_name = 'SKYRIZI'
  AND serious = '1';

-- Result 3. The case list: newest first. event_date is text in YYYYMMDD
--    form, so sorting the text also sorts the dates correctly.
SELECT safety_report_id, event_date, reaction, country, patient_age
FROM events
WHERE drug_name = 'SKYRIZI'
  AND serious = '1'
ORDER BY event_date DESC, safety_report_id
LIMIT 10;

-- Result 4. How many different reactions do the serious reports describe?
SELECT COUNT(DISTINCT reaction) AS distinct_serious_reactions
FROM events
WHERE drug_name = 'SKYRIZI'
  AND serious = '1';

-- Result 5. In the case list above, which rows have no age recorded?
SELECT COUNT(*) AS serious_reports_without_age
FROM events
WHERE drug_name = 'SKYRIZI'
  AND serious = '1'
  AND patient_age IS NULL;
