-- ============================================================
-- Session 3.3 · Warm-Up
-- "One Table, Three Files"
-- Question: the tech-fest committee keeps its team list in DuckDB
-- and must share it as CSV, JSON and Parquet. Which file brings
-- the table back exactly as it was?
-- Data: an invented table of four teams (toy data, typed below)
-- ============================================================

-- Where to WRITE. run_query.py makes DuckDB look for files to READ
-- in the repo root (file_search_path), wherever you run from. COPY
-- TO ignores that setting and writes relative to the folder you run
-- from. repo_file() builds the full path from the repo root.
CREATE OR REPLACE MACRO repo_file(p) AS
    current_setting('file_search_path') || '/' || p;

-- The original table, with a type chosen for every column.
CREATE OR REPLACE TABLE teams (
    team_code   VARCHAR,       -- an ID: never do sums on it
    college_pin VARCHAR,       -- a PIN code is a label, not a number
    members     INTEGER,
    fee         DECIMAL(7,2),  -- exact money, two decimals
    registered  DATE
);
INSERT INTO teams VALUES
    ('T07', '560001', 4, 1200.00, DATE '2026-01-12'),
    ('T11', '411001', 3,  950.50, DATE '2026-01-15'),
    ('T19', '110016', 5, 1500.00, DATE '2026-02-02'),
    ('T23', '600036', 2,  700.25, DATE '2026-02-09');

-- Write the same table three times, next to your .sql folder.
COPY teams TO (repo_file('week03/session_3_3/fest_teams.csv'));
COPY teams TO (repo_file('week03/session_3_3/fest_teams.json'));
COPY teams TO (repo_file('week03/session_3_3/fest_teams.parquet'))
    (FORMAT parquet);

-- Result 1. The original table.
SELECT * FROM teams ORDER BY team_code;

-- Result 2. Each file read back with no options: the type DuckDB
-- gives every column, beside the type we chose. A CSV holds only
-- text, so DuckDB guesses the types again; JSON keeps "quoted text"
-- as text but has only one kind of number; Parquet stores the types.
WITH original AS (
    SELECT column_name, column_type
    FROM (DESCRIBE SELECT * FROM teams)
), from_csv AS (
    SELECT column_name, column_type
    FROM (DESCRIBE SELECT * FROM 'week03/session_3_3/fest_teams.csv')
), from_json AS (
    SELECT column_name, column_type
    FROM (DESCRIBE SELECT * FROM 'week03/session_3_3/fest_teams.json')
), from_parquet AS (
    SELECT column_name, column_type
    FROM (DESCRIBE SELECT * FROM 'week03/session_3_3/fest_teams.parquet')
)
SELECT o.column_name,
       o.column_type AS original,
       c.column_type AS csv,
       j.column_type AS json,
       p.column_type AS parquet
FROM original o
JOIN from_csv     c USING (column_name)
JOIN from_json    j USING (column_name)
JOIN from_parquet p USING (column_name)
ORDER BY o.column_name;

-- Result 3. What the CSV's guess means: college_pin came back as a
-- number, so DuckDB lets you do arithmetic on a PIN code.
SELECT team_code, college_pin, college_pin + 1 AS pin_plus_one,
       fee
FROM 'week03/session_3_3/fest_teams.csv'
ORDER BY team_code;

-- Result 4. The size of each file in bytes. parse_filename() keeps
-- only the file's own name, without the folders.
SELECT parse_filename(filename) AS file, size AS bytes
FROM read_blob('week03/session_3_3/fest_teams.*')
ORDER BY file;
