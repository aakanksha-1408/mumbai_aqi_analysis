-- =====================================================================
-- 01_clean.sql : turn raw_readings (all text) into clean_readings
--   1. Convert text to numbers; 'NA' and blanks become missing values
--   2. Remove impossible values (negatives, sensor spikes)
--   3. Remove duplicate station-day rows
--   4. Standardise station names using dim_station
--   5. Add month, season and AQI category columns (CPCB-style breakpoints)
-- =====================================================================

DROP TABLE IF EXISTS dim_station;
CREATE TABLE dim_station (
    station_id   INTEGER PRIMARY KEY,
    station_name TEXT NOT NULL
);
INSERT INTO dim_station (station_id, station_name) VALUES
    (1, 'Bandra Kurla Complex'),
    (2, 'Chembur'),
    (3, 'Kurla'),
    (4, 'Andheri East'),
    (5, 'Mazgaon'),
    (6, 'Worli'),
    (7, 'Malad'),
    (8, 'Borivali');

DROP TABLE IF EXISTS clean_readings;
CREATE TABLE clean_readings AS
WITH typed AS (                           -- step 1: text -> numbers
    SELECT
        CAST(station_id AS INTEGER) AS station_id,
        DATE(reading_date)          AS reading_date,
        CASE WHEN UPPER(TRIM(pm25)) IN ('', 'NA', 'NAN', 'NULL') THEN NULL
             ELSE CAST(TRIM(pm25) AS REAL) END AS pm25,
        CASE WHEN UPPER(TRIM(pm10)) IN ('', 'NA', 'NAN', 'NULL') THEN NULL
             ELSE CAST(TRIM(pm10) AS REAL) END AS pm10,
        rowid                        AS src_row
    FROM raw_readings
),
ranked AS (                               -- step 3: keep one row per station per day
    SELECT t.*,
           ROW_NUMBER() OVER (PARTITION BY station_id, reading_date
                              ORDER BY (pm25 IS NULL), src_row) AS rn
    FROM typed t
),
valid AS (                                -- steps 2 and 4: range checks, clean names
    SELECT
        r.station_id,
        d.station_name,
        r.reading_date,
        CASE WHEN r.pm25 BETWEEN 0 AND 500 THEN r.pm25 END AS pm25,
        CASE WHEN r.pm10 BETWEEN 0 AND 600 THEN r.pm10 END AS pm10
    FROM ranked r
    JOIN dim_station d ON d.station_id = r.station_id
    WHERE r.rn = 1
),
categorised AS (                          -- step 5a: category per pollutant (1 = Good ... 6 = Severe)
    SELECT v.*,
        CASE WHEN pm25 IS NULL THEN NULL
             WHEN pm25 <= 30  THEN 1
             WHEN pm25 <= 60  THEN 2
             WHEN pm25 <= 90  THEN 3
             WHEN pm25 <= 120 THEN 4
             WHEN pm25 <= 250 THEN 5
             ELSE 6 END AS pm25_rank,
        CASE WHEN pm10 IS NULL THEN NULL
             WHEN pm10 <= 50  THEN 1
             WHEN pm10 <= 100 THEN 2
             WHEN pm10 <= 250 THEN 3
             WHEN pm10 <= 350 THEN 4
             WHEN pm10 <= 430 THEN 5
             ELSE 6 END AS pm10_rank
    FROM valid v
),
overall AS (                              -- step 5b: overall AQI = the worse of the two
    SELECT c.*,
        CASE WHEN pm25_rank IS NULL AND pm10_rank IS NULL THEN NULL
             ELSE MAX(COALESCE(pm25_rank, 0), COALESCE(pm10_rank, 0)) END AS aqi_rank
    FROM categorised c
)
SELECT
    station_id,
    station_name,
    reading_date,
    STRFTIME('%Y-%m', reading_date) AS year_month,
    CAST(STRFTIME('%m', reading_date) AS INTEGER) AS month_num,
    CASE WHEN STRFTIME('%m', reading_date) IN ('12', '01', '02') THEN 'Winter'
         WHEN STRFTIME('%m', reading_date) IN ('03', '04', '05') THEN 'Summer'
         WHEN STRFTIME('%m', reading_date) IN ('06', '07', '08', '09') THEN 'Monsoon'
         ELSE 'Post-Monsoon' END AS season,
    pm25,
    pm10,
    aqi_rank,
    CASE aqi_rank
        WHEN 1 THEN 'Good'
        WHEN 2 THEN 'Satisfactory'
        WHEN 3 THEN 'Moderately Polluted'
        WHEN 4 THEN 'Poor'
        WHEN 5 THEN 'Very Poor'
        WHEN 6 THEN 'Severe'
    END AS aqi_category,
    CASE WHEN aqi_rank IS NULL THEN NULL
         WHEN aqi_rank >= 4 THEN 1
         ELSE 0 END AS is_poor_plus            -- 1 = Poor or worse
FROM overall;
