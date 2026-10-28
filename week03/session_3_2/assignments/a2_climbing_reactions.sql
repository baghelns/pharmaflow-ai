-- ============================================================
-- Session 3.2 · Assignment 2 (Intermediate) · Solution
-- "Which Reactions Are Climbing the Ranking?"
-- Business question: compare each reaction's rank in 2025 with its
-- rank in 2026 (January to June), find the biggest climbers in the
-- 2026 top 10, and check whether one drug explains each climb.
-- ============================================================

CREATE OR REPLACE VIEW events AS
SELECT *,
       CAST(strptime(event_date, '%Y%m%d') AS DATE) AS report_date
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'});

-- Reports per reaction in each period, with the period's total.
CREATE OR REPLACE TABLE reaction_ranks AS
WITH counts AS (
    SELECT reaction,
           CASE WHEN year(report_date) = 2025 THEN '2025'
                ELSE '2026 H1' END AS period,
           COUNT(*) AS reports
    FROM events
    WHERE year(report_date) IN (2025, 2026)
    GROUP BY reaction, period
)
SELECT reaction, period, reports,
       round(100.0 * reports / SUM(reports) OVER (PARTITION BY period), 2)
                                                   AS pct_of_period,
       RANK() OVER (PARTITION BY period ORDER BY reports DESC) AS rnk
FROM counts;

-- One row per reaction: its 2025 and 2026 H1 figures side by side.
-- A FULL OUTER JOIN keeps reactions seen in only one of the periods.
CREATE OR REPLACE TABLE side_by_side AS
SELECT COALESCE(a.reaction, b.reaction) AS reaction,
       a.reports AS n_2025,  a.rnk AS rank_2025, a.pct_of_period AS pct_2025,
       b.reports AS n_2026,  b.rnk AS rank_2026, b.pct_of_period AS pct_2026
FROM (SELECT * FROM reaction_ranks WHERE period = '2025') AS a
FULL OUTER JOIN (SELECT * FROM reaction_ranks WHERE period = '2026 H1') AS b
     ON a.reaction = b.reaction;

-- Result 1. Size of each period (2026 covers six months only).
SELECT period, COUNT(*) AS reactions, SUM(reports) AS reports
FROM reaction_ranks
GROUP BY period
ORDER BY period;

-- Result 2. The 2026 H1 top 10 (ties included), with the 2025 rank and
-- the climb (a positive climb means the reaction moved up).
SELECT reaction, n_2025, rank_2025, n_2026, rank_2026,
       rank_2025 - rank_2026 AS climb
FROM side_by_side
WHERE rank_2026 <= 10
ORDER BY rank_2026, reaction;

-- Result 3. The biggest fall: 2025 top-10 reactions that dropped out.
SELECT reaction, n_2025, rank_2025, n_2026, rank_2026
FROM side_by_side
WHERE rank_2025 <= 10 AND (rank_2026 > 10 OR rank_2026 IS NULL)
ORDER BY rank_2025, reaction;

-- Result 4. For the two biggest climbers, the share of their 2026 H1
-- reports that came from the single most-reported drug.
WITH climbers AS (
    SELECT reaction
    FROM side_by_side
    WHERE rank_2026 <= 10
    ORDER BY rank_2025 - rank_2026 DESC, reaction
    LIMIT 2
),
by_drug AS (
    SELECT reaction, drug_name, COUNT(*) AS reports,
           round(100.0 * COUNT(*)
                 / SUM(COUNT(*)) OVER (PARTITION BY reaction), 1)
                                                AS pct_of_reaction,
           ROW_NUMBER() OVER (PARTITION BY reaction
                              ORDER BY COUNT(*) DESC, drug_name) AS rn
    FROM events
    WHERE year(report_date) = 2026
      AND reaction IN (SELECT reaction FROM climbers)
    GROUP BY reaction, drug_name
)
SELECT reaction, drug_name AS top_drug, reports, pct_of_reaction
FROM by_drug
WHERE rn = 1
ORDER BY reaction;
