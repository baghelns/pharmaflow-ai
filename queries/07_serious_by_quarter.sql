-- ============================================================
-- PharmaFlow SQL Library · 07_serious_by_quarter.sql
-- Question : How many serious reports arrive each quarter, and how does each
--            quarter compare with the one before?
-- Asked by : Pharmacovigilance Lead (Sessions 2.2 and 3.2)
-- Source   : data/raw/adverse_events_10k.csv
-- Output   : data/processed/library/07_serious_by_quarter.parquet (8 rows)
-- Checked  : 376, 409, 320, 434, 351, 352, 248, 427 serious; 2026 Q1 -29.5%,
--            2026 Q2 +72.2%
-- Notes    : Every quarter has reports, so LAG needs no calendar here. 2026
--            Q1 holds the bulk submissions (see 08).
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

CREATE OR REPLACE TABLE answer AS
WITH quarters AS (
    SELECT CAST(date_trunc('quarter', report_date) AS DATE) AS qtr,
           COUNT(*) FILTER (WHERE serious = '1') AS serious_reports
    FROM events
    GROUP BY qtr
)
SELECT qtr,
       strftime(qtr, '%Y') || ' Q' || quarter(qtr) AS quarter_label,
       serious_reports,
       ROUND(100.0 * (serious_reports
                      - LAG(serious_reports) OVER (ORDER BY qtr))
             / LAG(serious_reports) OVER (ORDER BY qtr), 1) AS pct_change
FROM quarters;

-- Save the answer for other teams.
COPY answer
TO (repo_file('data/processed/library/07_serious_by_quarter.parquet'))
    (FORMAT parquet);

-- Show the answer.
SELECT quarter_label, serious_reports, pct_change FROM answer ORDER BY qtr;
