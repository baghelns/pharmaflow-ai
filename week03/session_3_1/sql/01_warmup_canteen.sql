-- ============================================================
-- Session 3.1 · Warm-Up · "The Canteen, in SQL"
-- Business question: which canteen items sell, which never sell,
-- and which orders name an item the menu does not have?
-- Data: two small invented tables, created right here.
-- ============================================================

CREATE OR REPLACE TABLE menu (item VARCHAR, price INTEGER);
INSERT INTO menu VALUES
    ('Chai', 15), ('Samosa', 20), ('Vada Pav', 25), ('Idli', 30);

CREATE OR REPLACE TABLE orders (order_id INTEGER, item VARCHAR,
                                qty INTEGER);
INSERT INTO orders VALUES
    (1, 'Chai', 2), (2, 'Samosa', 1), (3, 'Chai', NULL),
    (4, 'Poha', 1), (5, 'Vada Pav', 3);

-- Result 1. SELECT, WHERE, ORDER BY, LIMIT: the two dearest items under 30
SELECT item, price
FROM menu
WHERE price < 30
ORDER BY price DESC
LIMIT 2;

-- Result 2. GROUP BY: COUNT(*) counts rows; COUNT(qty) skips the NULL qty
SELECT item,
       COUNT(*)   AS order_rows,
       COUNT(qty) AS rows_with_qty,
       SUM(qty)   AS cups_or_plates
FROM orders
GROUP BY item
ORDER BY item;

-- Result 3. INNER JOIN keeps only orders whose item is on the menu
SELECT o.order_id, o.item, m.price
FROM orders AS o
INNER JOIN menu AS m ON o.item = m.item
ORDER BY o.order_id;

-- Result 4. LEFT JOIN keeps every order; Poha gets a NULL price
SELECT o.order_id, o.item, m.price
FROM orders AS o
LEFT JOIN menu AS m ON o.item = m.item
ORDER BY o.order_id;

-- Result 5. RIGHT JOIN keeps every menu item; Idli has no order
SELECT o.order_id, m.item, m.price
FROM orders AS o
RIGHT JOIN menu AS m ON o.item = m.item
ORDER BY m.item, o.order_id;

-- Result 6. FULL OUTER JOIN keeps both sides: Poha AND Idli appear
SELECT o.order_id,
       COALESCE(o.item, m.item) AS item,
       m.price
FROM orders AS o
FULL OUTER JOIN menu AS m ON o.item = m.item
ORDER BY item, o.order_id;

-- Result 7. Row counts of the four joins side by side
SELECT
    (SELECT COUNT(*) FROM orders o JOIN menu m
        ON o.item = m.item)                    AS inner_rows,
    (SELECT COUNT(*) FROM orders o LEFT JOIN menu m
        ON o.item = m.item)                    AS left_rows,
    (SELECT COUNT(*) FROM orders o RIGHT JOIN menu m
        ON o.item = m.item)                    AS right_rows,
    (SELECT COUNT(*) FROM orders o FULL OUTER JOIN menu m
        ON o.item = m.item)                    AS full_rows;
