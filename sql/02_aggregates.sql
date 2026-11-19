-- =====================================================================
-- 02_aggregates.sql : summary tables for the Excel workbook and Power BI
-- =====================================================================

-- PM2.5 / PM10 by month and station
DROP TABLE IF EXISTS agg_monthly_station;
CREATE TABLE agg_monthly_station AS
SELECT
    year_month,
    station_name,
    ROUND(AVG(pm25), 1) AS avg_pm25,
    ROUND(AVG(pm10), 1) AS avg_pm10,
    COUNT(*)            AS days_recorded,
    SUM(is_poor_plus)   AS poor_plus_days,
    ROUND(100.0 * SUM(is_poor_plus) / COUNT(aqi_rank), 1) AS poor_plus_pct
FROM clean_readings
GROUP BY year_month, station_name
ORDER BY year_month, station_name;

-- PM2.5 / PM10 by season and station
DROP TABLE IF EXISTS agg_season_station;
CREATE TABLE agg_season_station AS
SELECT
    season,
    CASE season WHEN 'Winter' THEN 1 WHEN 'Summer' THEN 2
                WHEN 'Monsoon' THEN 3 ELSE 4 END AS season_order,
    station_name,
    ROUND(AVG(pm25), 1) AS avg_pm25,
    ROUND(AVG(pm10), 1) AS avg_pm10,
    COUNT(*)            AS days_recorded
FROM clean_readings
GROUP BY season, station_name
ORDER BY season_order, station_name;

-- Whole-period summary per station
DROP TABLE IF EXISTS agg_station_summary;
CREATE TABLE agg_station_summary AS
SELECT
    station_name,
    ROUND(AVG(pm25), 1) AS avg_pm25,
    ROUND(AVG(pm10), 1) AS avg_pm10,
    COUNT(pm25)         AS valid_pm25_days,
    COUNT(pm10)         AS valid_pm10_days,
    ROUND(100.0 * SUM(is_poor_plus) / COUNT(aqi_rank), 1) AS poor_plus_pct
FROM clean_readings
GROUP BY station_name
ORDER BY avg_pm25 DESC;

-- Count of station-days in each AQI category, per month
DROP TABLE IF EXISTS agg_category_monthly;
CREATE TABLE agg_category_monthly AS
SELECT
    year_month,
    aqi_rank,
    aqi_category,
    COUNT(*) AS days
FROM clean_readings
WHERE aqi_category IS NOT NULL
GROUP BY year_month, aqi_rank, aqi_category
ORDER BY year_month, aqi_rank;
