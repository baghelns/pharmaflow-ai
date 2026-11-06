-- Exercise 1: the committed answer to each of the five questions, read
-- straight from the SQL library's Parquet files (nothing is recomputed).

-- 1. Q1: the top ten drugs
SELECT drug_name, reports, pct_serious
FROM 'data/processed/library/03_top10_drugs.parquet'
ORDER BY reports DESC, drug_name;

-- 2. Q2: serious reports per quarter
SELECT quarter_label, serious_reports, pct_change
FROM 'data/processed/library/07_serious_by_quarter.parquet'
ORDER BY qtr;

-- 3. Q3: the most and least often serious reaction categories
SELECT reaction_category, reports, pct_serious
FROM 'data/processed/library/06_reaction_categories.parquet'
ORDER BY pct_serious DESC, reaction_category;

-- 4. Q4: the drug classes with more than 100 reports
SELECT CASE WHEN length(drug_class) > 30
            THEN left(drug_class, 29) || '…' ELSE drug_class END AS class_label,
       reports, drugs, pct_serious
FROM 'data/processed/library/05_drug_classes.parquet'
ORDER BY reports DESC, drug_class;

-- 5. Q5: missing values, and the bulk-submission days in total
SELECT column_name, blanks, pct_blank
FROM 'data/processed/library/02_missing_values.parquet'
WHERE blanks > 0
ORDER BY blanks DESC, column_name;

SELECT COUNT(*) AS bulk_days, CAST(SUM(reports) AS BIGINT) AS bulk_reports
FROM 'data/processed/library/08_bulk_submissions.parquet';
