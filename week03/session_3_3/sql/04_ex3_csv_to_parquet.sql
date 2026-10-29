-- ============================================================
-- Session 3.3 · Exercise 3 · Advanced
-- "Hand Over the Clean Data as Parquet"
-- Business question: from now on data/processed keeps our cleaned
-- reports for other teams. Export them once as CSV and once as
-- Parquet, prove which file brings the data back unchanged, and
-- show what each costs in space.
-- Data: data/raw/adverse_events_10k.csv (6,218 reports); writes
-- three files to data/processed/
-- ============================================================

CREATE OR REPLACE MACRO repo_file(p) AS
    current_setting('file_search_path') || '/' || p;

-- The clean table (CTAS): IDs and codes as text, age as a whole
-- number, and the report date as a real DATE.
CREATE OR REPLACE TABLE events_clean AS
SELECT safety_report_id,
       drug_name,
       reaction,
       serious,
       CAST(patient_age AS INTEGER) AS patient_age,
       patient_age_unit,
       country,
       CAST(strptime(event_date, '%Y%m%d') AS DATE) AS report_date
FROM read_csv('data/raw/adverse_events_10k.csv',
              types = {'safety_report_id': 'VARCHAR',
                       'serious': 'VARCHAR',
                       'patient_age_unit': 'VARCHAR',
                       'event_date': 'VARCHAR'})
ORDER BY safety_report_id;

COPY events_clean TO (repo_file('data/processed/events_clean.csv'));
COPY events_clean TO (repo_file('data/processed/events_clean.parquet'))
    (FORMAT parquet);
COPY events_clean TO (repo_file('data/processed/events_clean_zstd.parquet'))
    (FORMAT parquet, COMPRESSION zstd);

-- Result 1. The type of every column: in the table, and in each
-- file read back with no options.
WITH t AS (
    SELECT column_name, column_type
    FROM (DESCRIBE SELECT * FROM events_clean)
), c AS (
    SELECT column_name, column_type
    FROM (DESCRIBE SELECT * FROM 'data/processed/events_clean.csv')
), p AS (
    SELECT column_name, column_type
    FROM (DESCRIBE SELECT * FROM 'data/processed/events_clean.parquet')
)
SELECT t.column_name, t.column_type AS in_table,
       c.column_type AS csv_back, p.column_type AS parquet_back
FROM t
JOIN c USING (column_name)
JOIN p USING (column_name)
ORDER BY t.column_name;

-- Result 2. Does each file give back exactly the same rows?
-- EXCEPT returns the rows of the first query that the second does
-- not have; 0 in both directions means identical.
-- The CSV's columns came back with guessed types, so both sides
-- are cast to text (COLUMNS(*)::VARCHAR casts every column): the
-- check then compares the values themselves.
SELECT 'parquet' AS file,
       (SELECT COUNT(*) FROM (
            SELECT * FROM events_clean
            EXCEPT
            SELECT * FROM 'data/processed/events_clean.parquet'))
           AS missing_from_file,
       (SELECT COUNT(*) FROM (
            SELECT * FROM 'data/processed/events_clean.parquet'
            EXCEPT
            SELECT * FROM events_clean))
           AS extra_in_file
UNION ALL
SELECT 'csv',
       (SELECT COUNT(*) FROM (
            SELECT COLUMNS(*)::VARCHAR FROM events_clean
            EXCEPT
            SELECT COLUMNS(*)::VARCHAR
            FROM 'data/processed/events_clean.csv')),
       (SELECT COUNT(*) FROM (
            SELECT COLUMNS(*)::VARCHAR
            FROM 'data/processed/events_clean.csv'
            EXCEPT
            SELECT COLUMNS(*)::VARCHAR FROM events_clean));

-- Result 3. The size of each file in bytes, and in percent of the
-- original CSV in data/raw.
WITH files AS (
    SELECT parse_filename(filename) AS file, size AS bytes
    FROM read_blob(['data/raw/adverse_events_10k.csv',
                    'data/processed/events_clean.csv',
                    'data/processed/events_clean.parquet',
                    'data/processed/events_clean_zstd.parquet'])
)
SELECT file, bytes,
       ROUND(100.0 * bytes
             / MAX(bytes) FILTER (WHERE file = 'adverse_events_10k.csv')
                 OVER (), 1) AS pct_of_raw_csv
FROM files
ORDER BY bytes DESC, file;

-- Result 4. Inside the Parquet file: it stores each column
-- separately, compressed. parquet_metadata() lists every column
-- chunk with its size on disk.
SELECT path_in_schema AS column_name,
       type,
       compression,
       total_compressed_size AS bytes_on_disk,
       total_uncompressed_size AS bytes_unpacked
FROM parquet_metadata('data/processed/events_clean.parquet')
ORDER BY bytes_on_disk DESC, column_name;
