-- Exercise 2: is a drug-class ranking really a ranking of one drug?
-- For each class with more than 100 reports: its leading drug and the
-- share of the class's reports that drug holds.
SELECT CASE WHEN length(c.drug_class) > 30
            THEN left(c.drug_class, 29) || '…' ELSE c.drug_class END AS class_label,
       c.reports AS class_n,
       r.drug_name AS top_drug,
       r.reports AS drug_n,
       round(100.0 * r.reports / c.reports, 1) AS pct_of_class
FROM 'data/processed/library/05_drug_classes.parquet' AS c
JOIN 'data/processed/library/09_rank_in_class.parquet' AS r
  ON r.drug_class = c.drug_class AND r.rank_in_class = 1
ORDER BY pct_of_class DESC, c.drug_class;
