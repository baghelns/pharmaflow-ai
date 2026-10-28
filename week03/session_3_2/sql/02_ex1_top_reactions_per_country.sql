-- ============================================================
-- Session 3.2 · Exercise 1 · Beginner
-- "The Top 3 Reactions in Each Country"
-- Business question: for every country with at least 150 reports,
-- which three reactions are reported most often -- and what does
-- "top 3" mean when reactions tie?
-- Data: data/raw/adverse_events_10k.csv (6,218 reports)
-- ============================================================

-- The events view, with report_date as a real DATE (used from
-- Exercise 2 on; every 3.2 file creates the same view).
CREATE OR REPLACE VIEW events AS
SELECT *,
       CAST(strptime(event_date, '%Y%m%d') AS DATE) AS report_date
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

-- Reports per country and reaction, for the countries with 150+.
CREATE OR REPLACE TABLE country_reactions AS
WITH big_countries AS (
    SELECT country
    FROM events
    WHERE country IS NOT NULL
    GROUP BY country
    HAVING COUNT(*) >= 150
)
SELECT country, reaction, COUNT(*) AS reports
FROM events
WHERE country IN (SELECT country FROM big_countries)
GROUP BY country, reaction;

-- The three numberings side by side, kept in one table.
CREATE OR REPLACE TABLE ranked AS
SELECT country, reaction, reports,
       ROW_NUMBER() OVER (PARTITION BY country
                          ORDER BY reports DESC, reaction) AS row_num,
       RANK()       OVER (PARTITION BY country
                          ORDER BY reports DESC)           AS rnk,
       DENSE_RANK() OVER (PARTITION BY country
                          ORDER BY reports DESC)           AS dense_rnk
FROM country_reactions;

-- Result 1. Which countries qualify, and how many reports each has.
SELECT country, SUM(reports) AS reports,
       COUNT(*) AS different_reactions
FROM country_reactions
GROUP BY country
ORDER BY reports DESC, country;

-- Result 2. The answer: RANK() <= 3 keeps every reaction tied
-- for a top-3 place, so a country can show more than three rows.
SELECT country, reaction, reports, rnk
FROM ranked
WHERE rnk <= 3
ORDER BY country, rnk, reaction;

-- Result 3. How many rows "top 3" gives in each country, by method.
-- ROW_NUMBER always gives 3: it breaks ties by the tie-breaker you
-- wrote (here, the reaction's alphabetical order), not by the data.
SELECT country,
       COUNT(*) FILTER (WHERE row_num   <= 3) AS by_row_number,
       COUNT(*) FILTER (WHERE rnk       <= 3) AS by_rank,
       COUNT(*) FILTER (WHERE dense_rnk <= 3) AS by_dense_rank
FROM ranked
GROUP BY country
ORDER BY country;

-- Result 4. Canada close up: three reactions tie for second place.
SELECT reaction, reports, row_num, rnk, dense_rnk
FROM ranked
WHERE country = 'CA' AND dense_rnk <= 3
ORDER BY reports DESC, reaction;
