-- ============================================================
-- Session 3.2 · Warm-Up · "Two Chai Stalls, Four Days"
-- Business question: on which day did each stall sell the most,
-- how did each day compare with the day before, and how many cups
-- had each stall sold so far by the end of each day?
-- Data: one small invented table, created right here.
-- ============================================================

CREATE OR REPLACE TABLE sales (stall VARCHAR, day_no INTEGER,
                               day_name VARCHAR, cups INTEGER);
INSERT INTO sales VALUES
    ('Gate',    1, 'Mon', 40), ('Gate',    2, 'Tue', 55),
    ('Gate',    3, 'Wed', 55), ('Gate',    4, 'Thu', 30),
    ('Library', 1, 'Mon', 20), ('Library', 2, 'Tue', 35),
    ('Library', 3, 'Wed', 25), ('Library', 4, 'Thu', 35);

-- Result 1. WITH names a query so the next query can use it like a
-- table. Here: total cups per stall.
WITH stall_totals AS (
    SELECT stall, SUM(cups) AS total_cups
    FROM sales
    GROUP BY stall
)
SELECT stall, total_cups
FROM stall_totals
ORDER BY total_cups DESC, stall;

-- Result 2. A window function keeps every row. Three ways to number
-- the Gate stall's days from most cups to fewest; Tue and Wed tie.
SELECT day_name, cups,
       ROW_NUMBER() OVER (ORDER BY cups DESC, day_no) AS row_num,
       RANK()       OVER (ORDER BY cups DESC)         AS rnk,
       DENSE_RANK() OVER (ORDER BY cups DESC)         AS dense_rnk
FROM sales
WHERE stall = 'Gate'
ORDER BY cups DESC, day_no;

-- Result 3. PARTITION BY restarts the numbering for each stall.
SELECT stall, day_name, cups,
       RANK() OVER (PARTITION BY stall ORDER BY cups DESC) AS rank_in_stall
FROM sales
ORDER BY stall, rank_in_stall, day_no;

-- Result 4. LAG reads the previous row, LEAD the next one, inside
-- each stall in day order. The first day has no previous day: NULL.
SELECT stall, day_name, cups,
       LAG(cups)  OVER (PARTITION BY stall ORDER BY day_no) AS prev_day,
       cups - LAG(cups) OVER (PARTITION BY stall ORDER BY day_no)
                                                        AS change,
       LEAD(cups) OVER (PARTITION BY stall ORDER BY day_no) AS next_day
FROM sales
ORDER BY stall, day_no;

-- Result 5. A frame says which rows the window adds up. Running total
-- (every row so far) and a 2-day moving average (this day and the one
-- before).
SELECT stall, day_name, cups,
       SUM(cups) OVER (PARTITION BY stall ORDER BY day_no
                       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                   AS cups_so_far,
       AVG(cups) OVER (PARTITION BY stall ORDER BY day_no
                       ROWS BETWEEN 1 PRECEDING AND CURRENT ROW)
                                                   AS avg_2_days
FROM sales
ORDER BY stall, day_no;

-- Result 6. FIRST_VALUE and LAST_VALUE: the trap. With ORDER BY and no
-- frame, the window stops at the current row, so LAST_VALUE returns
-- the current row's own value. The full frame gives the real last day.
SELECT stall, day_name, cups,
       FIRST_VALUE(cups) OVER (PARTITION BY stall ORDER BY day_no)
                                                   AS first_day,
       LAST_VALUE(cups)  OVER (PARTITION BY stall ORDER BY day_no)
                                                   AS last_default,
       LAST_VALUE(cups)  OVER (PARTITION BY stall ORDER BY day_no
                       ROWS BETWEEN UNBOUNDED PRECEDING
                                AND UNBOUNDED FOLLOWING) AS last_day
FROM sales
ORDER BY stall, day_no;
